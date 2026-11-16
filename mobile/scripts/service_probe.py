#!/usr/bin/env python3
"""Read-only, bounded Slack/Gmail/iCloud probes. Credentials are prompted, never stored.

Outputs importable event evidence; never derives elapsed work time or phone provenance.
Only fixed official service endpoints are used. No messages are sent or marked read.
"""
import argparse
import datetime as dt
import email
import email.policy
import email.utils
import getpass
import imaplib
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

UTC = dt.timezone.utc
LIMITATIONS = [
    "Service events do not establish originating device, reading time, composition time, or continuous work.",
    "Incoming messages are context, not proof that the user read or acted on them.",
    "This is a bounded sample, not a complete history. Use event IDs to deduplicate desktop evidence.",
    "No Screen Time data is collected or exported by this probe."
]

def iso(value):
    return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")

def parse_time(value):
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise argparse.ArgumentTypeError("--since requires a timezone, e.g. 2026-11-15T12:00:00-08:00")
    return parsed.astimezone(UTC)

class NoRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Unexpected service redirect; credentials were not forwarded.")

def get_json(url, token):
    if urllib.parse.urlparse(url).hostname not in {"slack.com", "gmail.googleapis.com"}:
        raise ValueError("Unsupported service host.")
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token, "Accept": "application/json"})
    opener = urllib.request.build_opener(NoRedirects(), urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    try:
        with opener.open(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Service returned HTTP {exc.code}; check read permission, token expiry, and rate limits.") from None

def event(identifier, source, at, description, authored):
    return {"id": identifier, "source": source, "timestamp": iso(at), "description": description, "userAuthored": authored}

def is_work(headers, args):
    if args.work_account:
        return True
    addresses = {address.lower() for _, address in email.utils.getaddresses(
        [headers.get("from", ""), headers.get("to", ""), headers.get("cc", "")])}
    return bool(addresses.intersection({value.lower() for value in args.work_address}))

def slack(args):
    token = getpass.getpass("Slack read token (hidden; not stored): ")
    identity = get_json("https://slack.com/api/auth.test", token)
    if not identity.get("ok"):
        raise RuntimeError("Slack authentication failed: " + str(identity.get("error", "unknown")))
    source = "slack:" + identity["team_id"] + ":" + args.channel
    params = urllib.parse.urlencode({"channel": args.channel, "oldest": args.since.timestamp(), "limit": args.limit})
    payload = get_json("https://slack.com/api/conversations.history?" + params, token)
    if not payload.get("ok"):
        raise RuntimeError("Slack history failed: " + str(payload.get("error", "unknown")))
    events = []
    for message in payload.get("messages", []):
        if message.get("user") != args.user:
            continue  # Only the explicitly selected person's contributions.
        at = dt.datetime.fromtimestamp(float(message["ts"]), UTC)
        text = message.get("text", "")
        description = f"User-authored Slack message; {len(text)} characters; text not retained"
        if args.include_text:
            description = text[:1200]
        events.append(event(message["ts"], source, at, description, True))
    limitations = LIMITATIONS + ["Slack probe samples one selected conversation; thread replies require a separate conversations.replies request."]
    if payload.get("has_more"):
        limitations.append("More conversation history exists outside this bounded response.")
    return events, limitations

def gmail(args):
    token = getpass.getpass("Gmail OAuth access token with gmail.readonly or gmail.metadata (hidden): ")
    profile = get_json("https://gmail.googleapis.com/gmail/v1/users/me/profile", token)
    actual = profile["emailAddress"].lower()
    if actual != args.account.lower():
        raise RuntimeError("Authenticated Gmail account differs from --account; no messages were fetched.")
    base = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
    params = urllib.parse.urlencode({"labelIds": args.gmail_label, "maxResults": args.limit})
    listing = get_json(base + "?" + params, token)
    events = []
    for reference in listing.get("messages", []):
        message = get_json(base + "/" + urllib.parse.quote(reference["id"], safe="") + "?format=metadata", token)
        at = dt.datetime.fromtimestamp(int(message["internalDate"]) / 1000, UTC)
        headers = {h["name"].lower(): h["value"] for h in message.get("payload", {}).get("headers", [])}
        if at < args.since or not is_work(headers, args):
            continue
        authored = "SENT" in message.get("labelIds", [])
        subject = headers.get("subject", "(no subject)")[:200] if args.include_text else "subject not retained"
        events.append(event(message["id"], "gmail:" + actual, at,
                            ("Sent email; " if authored else "Mailbox event, not proof of reading; ") + subject, authored))
    return events, LIMITATIONS + [
        "Gmail internalDate is the service timestamp, not when the phone read or composed a message.",
        f"At most {args.limit} messages from label {args.gmail_label} inspected; filters can yield zero without proving no activity."
    ]

def icloud(args):
    password = getpass.getpass("iCloud app-specific password (not your Apple Account password; hidden): ")
    connection = imaplib.IMAP4_SSL("imap.mail.me.com", 993, ssl_context=ssl.create_default_context(), timeout=30)
    events = []
    try:
        connection.login(args.account, password)
        status, _ = connection.select(args.mailbox, readonly=True)  # EXAMINE, never SELECT writable.
        if status != "OK":
            raise RuntimeError("iCloud mailbox could not be opened read-only.")
        valid = connection.response("UIDVALIDITY")[1]
        validity = valid[0].decode() if valid and valid[0] else "unknown"
        # IMAP SINCE is day-granular. Apply the exact instant to INTERNALDATE below.
        status, data = connection.uid("search", None, "SINCE", args.since.strftime("%d-%b-%Y"))
        if status != "OK":
            raise RuntimeError("iCloud search failed.")
        uids = data[0].split()[-args.limit:] if data and data[0] else []
        for uid in uids:
            status, items = connection.uid("fetch", uid, "(UID INTERNALDATE BODY.PEEK[HEADER.FIELDS (DATE FROM TO CC SUBJECT MESSAGE-ID)])")
            if status != "OK":
                continue
            for item in items:
                if not isinstance(item, tuple):
                    continue
                match = re.search(rb'INTERNALDATE "([^"]+)"', item[0])
                if not match:
                    continue
                at = dt.datetime.strptime(match.group(1).decode(), "%d-%b-%Y %H:%M:%S %z").astimezone(UTC)
                message = email.message_from_bytes(item[1], policy=email.policy.default)
                headers = {name: str(message.get(name, "")) for name in ["from", "to", "cc", "subject"]}
                if at < args.since or not is_work(headers, args):
                    continue
                senders = {address.lower() for _, address in email.utils.getaddresses([headers["from"]])}
                sender_matches = args.account.lower() in senders
                subject = headers["subject"][:200] if args.include_text else "subject not retained"
                record = event(validity + ":" + uid.decode(), "icloud:" + args.account.lower() + ":" + args.mailbox, at,
                               ("From selected account; " if sender_matches else "Mailbox event, not proof of reading; ") + subject, False)
                record["authorshipEvidence"] = "From-address match only; authorship unverified" if sender_matches else "No authorship claim"
                events.append(record)
    finally:
        try:
            connection.logout()
        except (imaplib.IMAP4.error, OSError):
            pass
    return events, LIMITATIONS + [
        "iCloud probe uses TLS IMAP EXAMINE and BODY.PEEK; no SMTP, flag changes, or message body retrieval.",
        "INTERNALDATE is the server mailbox timestamp, not reading time. From-address matching alone does not prove authorship.",
        "Mail aliases may need a separate authored-address rule; currently the selected account address is used."
    ]

def write_report(path, provider, events, limitations):
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"schemaVersion": 1, "provider": provider, "collectedAt": iso(dt.datetime.now(UTC)),
               "events": events, "limitations": limitations}
    # Never overwrite an earlier evidence file; restrict access before writing.
    descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, "w") as output:
        json.dump(payload, output, indent=2); output.write("\n")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provider", choices=["slack", "gmail", "icloud"])
    parser.add_argument("--since", type=parse_time, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--account", help="Exact Gmail/iCloud account to read")
    parser.add_argument("--work-address", action="append", default=[], help="Exact work correspondent address; repeat as needed")
    parser.add_argument("--work-account", action="store_true", help="Explicitly designate the entire selected mailbox account as work")
    parser.add_argument("--channel", help="Selected Slack channel/conversation ID")
    parser.add_argument("--user", help="Slack user ID whose own messages are sampled")
    parser.add_argument("--gmail-label", default="SENT", help="Gmail label ID; defaults to SENT")
    parser.add_argument("--mailbox", default="Sent Messages", help="Exact iCloud IMAP mailbox name")
    parser.add_argument("--include-text", action="store_true", help="Explicitly retain Slack text or mail subjects in the local report")
    args = parser.parse_args()
    if not 1 <= args.limit <= 100:
        parser.error("--limit must be between 1 and 100")
    if args.since > dt.datetime.now(UTC):
        parser.error("--since must not be in the future")
    if args.provider == "slack" and (not args.channel or not args.user):
        parser.error("Slack requires --channel and --user")
    if args.provider != "slack" and (not args.account or not (args.work_address or args.work_account)):
        parser.error("Mail requires --account and either --work-address or explicit --work-account")
    if args.output.exists():
        parser.error("Output already exists; choose a new filename")
    try:
        events, limitations = {"slack": slack, "gmail": gmail, "icloud": icloud}[args.provider](args)
        write_report(args.output, args.provider, events, limitations)
    except (RuntimeError, ValueError, KeyError, OSError, imaplib.IMAP4.error) as exc:
        print(f"Probe failed: {type(exc).__name__}. {str(exc)[:200]}", file=sys.stderr)
        return 1
    print(f"Wrote {len(events)} bounded event records to {args.output}. Device and duration remain unknown.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
