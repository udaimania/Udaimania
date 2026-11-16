import datetime as dt
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("service_probe", Path(__file__).with_name("service_probe.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)

class ServiceProbeTests(unittest.TestCase):
    def args(self, **values):
        defaults = dict(work_account=False, work_address=["colleague@work.example"], account="me@icloud.com",
                        since=dt.datetime(2026, 11, 15, 0, 0, tzinfo=dt.timezone.utc), limit=25,
                        include_text=False, mailbox="Sent Messages", channel="C1", user="U1", gmail_label="SENT")
        return SimpleNamespace(**(defaults | values))

    def test_exact_work_filter_excludes_personal_and_substring_addresses(self):
        self.assertTrue(probe.is_work({"to": "Person <colleague@work.example>"}, self.args()))
        self.assertFalse(probe.is_work({"to": "othercolleague@work.example"}, self.args()))
        self.assertFalse(probe.is_work({"to": "friend@personal.example"}, self.args()))

    def test_naive_start_time_is_rejected(self):
        with self.assertRaises(Exception):
            probe.parse_time("2026-11-15T12:00:00")
        self.assertEqual(probe.parse_time("2026-11-15T12:00:00-08:00").hour, 20)

    def test_slack_retains_only_selected_authors_and_no_text_by_default(self):
        responses = [{"ok": True, "team_id": "T1"}, {"ok": True, "messages": [
            {"user": "U1", "ts": "1794700000.0", "text": "private test content"},
            {"user": "U2", "ts": "1794700001.0", "text": "someone else's work"}]}]
        with patch.object(probe.getpass, "getpass", return_value="secret"), patch.object(probe, "get_json", side_effect=responses):
            events, _ = probe.slack(self.args())
        self.assertEqual(len(events), 1)
        self.assertNotIn("private test content", json.dumps(events))
        self.assertNotIn("durationSeconds", events[0])
        self.assertEqual(events[0]["source"], "slack:T1:C1")

    def test_wrong_gmail_account_stops_before_message_access(self):
        with patch.object(probe.getpass, "getpass", return_value="secret"), patch.object(probe, "get_json", return_value={"emailAddress": "wrong@example.com"}) as request:
            with self.assertRaises(RuntimeError):
                probe.gmail(self.args(account="work@example.com"))
        self.assertEqual(request.call_count, 1)

    def test_gmail_uses_metadata_and_labels_and_filters_before_retention(self):
        at = int(dt.datetime(2026, 11, 15, 1, tzinfo=dt.timezone.utc).timestamp() * 1000)
        responses = [{"emailAddress": "work@example.com"}, {"messages": [{"id": "1"}, {"id": "2"}]},
                     {"id": "1", "internalDate": str(at), "labelIds": ["SENT"], "payload": {"headers": [
                         {"name": "To", "value": "colleague@work.example"}, {"name": "Subject", "value": "do not retain"}]}},
                     {"id": "2", "internalDate": str(at), "labelIds": ["SENT"], "payload": {"headers": [
                         {"name": "To", "value": "friend@personal.example"}]}}]
        with patch.object(probe.getpass, "getpass", return_value="secret"), patch.object(probe, "get_json", side_effect=responses) as request:
            events, _ = probe.gmail(self.args(account="work@example.com"))
        self.assertEqual(len(events), 1)
        self.assertNotIn("do not retain", json.dumps(events))
        self.assertIn("format=metadata", request.call_args_list[2].args[0])

    def test_icloud_is_readonly_peek_and_uses_internaldate(self):
        class FakeIMAP:
            def __init__(self): self.calls = []
            def login(self, account, password): self.calls.append(("login", account))
            def select(self, mailbox, readonly): self.calls.append(("select", mailbox, readonly)); return "OK", [b"1"]
            def response(self, name): return "UIDVALIDITY", [b"9"]
            def uid(self, command, *args):
                self.calls.append((command, *args))
                if command == "search": return "OK", [b"8"]
                return "OK", [(b'1 (UID 8 INTERNALDATE "15-Nov-2026 01:00:00 +0000")',
                    b"From: me@icloud.com\r\nTo: colleague@work.example\r\nSubject: secret\r\nDate: Fri, 1 Jan 2010 00:00:00 +0000\r\n\r\n")]
            def logout(self): self.calls.append(("logout",))
        client = FakeIMAP()
        with patch.object(probe.getpass, "getpass", return_value="app-password"), patch.object(probe.imaplib, "IMAP4_SSL", return_value=client):
            events, _ = probe.icloud(self.args())
        self.assertIn(("select", "Sent Messages", True), client.calls)
        self.assertTrue(any("BODY.PEEK" in str(call) for call in client.calls))
        self.assertFalse(any(call[0] in ["store", "append", "expunge"] for call in client.calls))
        self.assertEqual(events[0]["timestamp"], "2026-11-15T01:00:00Z")
        self.assertFalse(events[0]["userAuthored"])
        self.assertIn("unverified", events[0]["authorshipEvidence"])
        self.assertNotIn("secret", json.dumps(events))

    def test_report_has_restrictive_permissions_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            probe.write_report(path, "slack", [], probe.LIMITATIONS)
            self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(path.read_text())["schemaVersion"], 1)
            with self.assertRaises(FileExistsError):
                probe.write_report(path, "slack", [], [])

    def test_credentials_cannot_follow_service_redirect(self):
        with self.assertRaises(RuntimeError):
            probe.NoRedirects().redirect_request(None, None, 302, "", {}, "https://example.com")

if __name__ == "__main__":
    unittest.main()
