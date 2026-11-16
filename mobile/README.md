# Udaimania Capture Lab

An iPhone feasibility prototype for work continuity away from the Mac. It tests three separate signals: user-started screen-text sampling, read-only Slack/mail service events, and an optional isolated Screen Time report. It does not yet provide continuous day coverage, production OAuth onboarding, Mac synchronization, or team publishing.

## Status: paused

Paused at the user's request on 15 November 2026. Resume only when the user asks to return to the phone companion. Start by reading `VALIDATION.md`: the first physical-device synthetic trial demonstrated cross-app capture but substantially undercounted static reading. Family Controls signing was blocked for the Personal Team. The user's real work accounts are excluded from testing.

The next session should verify the current checkout and device/signing state, then agree on the next measurement experiment before extending the prototype. The macOS app and visual redesign can proceed independently while this work remains paused.

## Build and install

Requires Xcode 27 or later and a physical iPhone running iOS 27 or later for ScreenCaptureKit. The simulator can exercise the UI and imports; its build explicitly disables device capture and generates no capture evidence.

Open `UdaimaniaCaptureLab.xcodeproj`. Select **Capture Lab** for the basic app, or **Capture Lab + Screen Time** for the variant with a Device Activity report extension. The two apps have separate bundle IDs and storage. Neither changes the macOS app.

Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` and set `CAPTURE_LAB_TEAM` to your team ID. Local signing configuration is ignored by Git. Sign into Xcode, enable Developer Mode on the phone, and trust the development certificate when iOS asks. The optional Family Controls target requires a team whose provisioning supports that capability; a Personal Team was explicitly rejected during the initial test.

From the repository root:

```sh
python3 mobile/scripts/generate_project.py
swift test --package-path mobile/CaptureCore --scratch-path build/CaptureCore
python3 -m unittest discover -s mobile/scripts -p 'test_*.py' -v
xcodebuild -project mobile/UdaimaniaCaptureLab.xcodeproj \
  -scheme 'Capture Lab' -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/CaptureLab CODE_SIGNING_ALLOWED=NO build
```

For a device, select its destination in Xcode and Run. The equivalent command accepts `-destination 'id=YOUR_DEVICE_UDID' -allowProvisioningUpdates -allowProvisioningDeviceRegistration`; do not disable code signing. `scripts/generate_project.py` reproducibly generates the checked-in project using Python's standard library. Change that script when changing targets/build settings.

## First capture trial

For account-free testing, build the **Synthetic Test Scenes** scheme and install its separate **Udaimania Scenes** app. In Capture Lab's Sources tab, choose **Use synthetic test rules** (available when the rule list is empty). Start capture, then launch Scenes and begin its 150-second reference sequence. It displays five 30-second stages: static synthetic Slack, changing synthetic Slack, work email, personal email, and explicit other use. The personal-email stage is an unknown negative control. None connects to a service, sends a message, or reads an account.

The fixture logs step transitions using the same iPhone's monotonic clock, independently of OCR. Changing foreground apps interrupts the reference run. Each run writes a new `Library/Application Support/reference-UUID.json` inside its app container. Capture Lab stores `Library/Application Support/CaptureLab/lab.json` in its own container. After stopping capture, retrieve the two files through Xcode/devicectl and compare them:

```sh
python3 mobile/scripts/analyze_synthetic_trial.py \
  --lab mobile/results/lab.json --reference mobile/results/reference-UUID.json
```

Use files from the same iPhone boot. The analysis clips estimated intervals to each independently timed stage and reports unknown time, wrong work matches in negative controls, and sample conditions. **Fixture results cannot establish real Slack/Gmail/iCloud behavior.** The current user's work accounts are excluded from testing.

1. In **Sources**, add both a visible application cue and a work-specific channel/mailbox/account marker. Use markers that actually appear together on the tested screen. Neither marker authenticates the foreground app or account. Rules are frozen during a trial.
2. Leave **Keep matched work text excerpts** off for the first test. This records classification, character counts, timings and lifecycle information without retaining OCR text. Enable it explicitly for a later content-quality trial if needed.
3. Name the trial in **Capture**, start it, and accept the system's full-display sharing choice. Switch to the target app. Use a separate stopwatch to record actual time in the tested activity.
4. Return and stop. Sessions have a five-minute cap. The system capture control can also stop them. Inspect **Results**, enter the independent duration/activity and note interruptions. Record zero-reference false-positive tests in the notes; the relative-error comparison requires a positive denominator.
5. Prepare a JSON report. Sharing requires an explicit user action. Reports include rule markers and any retained work excerpts, so review their destination.

ScreenCaptureKit on iOS does not expose the Mac's app exclusion controls. This prototype receives the full display during the session, processes frames locally, and discards images. It requests no microphone or camera capture and writes no video. Frames are not restricted to Slack or mail at the system boundary. The app's own active UI is excluded from OCR to reduce self-matching of configured markers. Full-display capture is a controlled test mechanism, not a decided production architecture.

## What time means

Session elapsed time uses a monotonic clock. OCR is attempted at most once every two seconds; this does **not** reduce the system stream's frame rate or guarantee two-second delivery. Only adjacent readable samples with the same non-unknown class, no more than six seconds apart, contribute estimated duration. Leading/trailing time, transitions, idle/blank frames, callback gaps, and unmatched text remain **unclassified**. Observed non-work requires its own matching rule; silence is never converted to non-work.

This intentionally sacrifices coverage to avoid invented work time. It still cannot establish reading attention. Two matching endpoints can hide an intervening switch. A missing account marker can make legitimate work unknown; incidental marker text can cause false positives. Inspect both coverage and stopwatch error, and run negative controls. Absolute timing error is `abs(estimate - reference) / reference`; it is not classification accuracy. The app also reports callback gaps, OCR processing time, and coarse battery changes. Charging-sensitive battery percentages are not an energy benchmark.

## Service probes

`scripts/service_probe.py` supports Slack, Gmail and iCloud. It runs on the Mac, reads a bounded selection, and writes schema-version-1 JSON that **Sources → Import service-probe JSON** can read. Credentials are entered through hidden terminal prompts, never command arguments, report fields or checked-in files. A connected service plugin can independently validate accessible events, but its credentials are not reusable by the iPhone app or this script.

Examples below use placeholders. Use an explicit timezone and the beginning of the actual trial window. Reports are ignored by Git, created with mode 0600 and never overwritten.

```sh
python3 mobile/scripts/service_probe.py slack \
  --channel CHANNEL_ID --user USER_ID --since '2026-11-15T12:00:00-08:00' \
  --output mobile/results/slack-trial-01.json

python3 mobile/scripts/service_probe.py gmail \
  --account 'you@work.example' --work-address 'colleague@work.example' \
  --since '2026-11-15T12:00:00-08:00' --output mobile/results/gmail-trial-01.json

python3 mobile/scripts/service_probe.py icloud \
  --account 'you@icloud.com' --work-address 'colleague@work.example' \
  --mailbox 'Sent Messages' --since '2026-11-15T12:00:00-08:00' \
  --output mobile/results/icloud-trial-01.json
```

- Slack needs an authorized token with history access to the selected conversation. It keeps only the selected user's messages from one bounded history response. Thread replies need a separate replies request and are not collected by this prototype.
- Gmail needs a suitable OAuth access token with `gmail.metadata` or `gmail.readonly`. It verifies the authenticated account before fetching message metadata. It defaults to `SENT`; use `--gmail-label` for another label ID. It does not fetch bodies. The probe filters the bounded response locally, so zero matches is not evidence of zero activity.
- iCloud needs an app-specific password and the exact IMAP mailbox name. It uses TLS, read-only EXAMINE and BODY.PEEK for selected headers. It performs no SMTP or flag changes. A From-address match is explicitly unverified authorship, and aliases are not automatically recognized.
- Mail requires exact selected correspondent addresses, or `--work-account` to explicitly designate the entire account as work. Do not designate a mixed personal account as all work.
- `--include-text` explicitly retains Slack text (up to 1,200 characters) or email subjects (up to 200). Default reports retain neither.

Service events have **unknown duration and device**. Sent messages are work evidence, not evidence of time spent reading, composing, or using an iPhone. No message or email is sent by the prototype. Imported provider limitations are retained in the app and export. Production service integrations still need their own OAuth/app registration and authorization flow.

## Optional Screen Time comparison

The full variant requests individual Family Controls authorization and lets the user select applications. The DeviceActivity report renders per-device, per-app durations, pickups, and the last update time for today's filter. No data or an empty report is not zero use. Reports may be delayed and may include more than one eligible iPhone; inspect device labels.

The extension has no network, shared App Group, report export, or data-copy channel. It respects DeviceActivity report isolation. App-level durations cannot distinguish work/personal accounts within Slack, Gmail or Apple Mail. The newer regional FamilyActivityData access is not assumed available to this user. Screen Time is therefore a visible comparison source, not a production synchronization implementation.

## Device test matrix

Run each activity in a separate named session, ideally three repetitions. Keep the phone and reference stopwatch visible to the operator.

| Trial | Independent observation | What to inspect |
| --- | --- | --- |
| Slack: read without sending for 60 seconds | Foreground duration, exact visible work channel | OCR availability, unchanged-screen callbacks, coverage, false unknowns; no new sent event expected |
| Slack: write a harmless message in your own test conversation | Compose duration and send time | Draft visibility vs final message, service-event delay; no invented duration from timestamp |
| Gmail: work account, then personal account | Time in each account and transitions | Whether account markers remain visible; work false positives on personal screen |
| iCloud: selected work mailbox, then mixed inbox | Work/personal message context | Context ambiguity, marker visibility, no inference of reading from server metadata |
| Explicit non-work app, then lock for 30 seconds | App duration vs locked interval | Other-use rule behavior, unclassified locked time, interruption and recovery |
| Offline, rotation, notification and system-stop cases | Exact condition change times | Lost callbacks, OCR orientation, redacted content, truthful end reason |
| Repeated five-minute trials unplugged | Battery/thermal/charging state and coverage | Session cap, sustained delivery; coarse battery data alone cannot prove energy efficiency |

Pre-register acceptance targets before evaluating a product claim. A suggested feasibility gate is no work matches in negative controls, at least 90% of operator-observed work duration represented, and absolute error no greater than the larger of 5 seconds or 10% per stable one-minute trial. These are proposed gates, **not measured results or guarantees**. Passing short trials does not establish 24-hour reliability or App Store approval.

See `VALIDATION.md` for the actual verification record and remaining hardware tests.

## Primary platform references

- [Apple: capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios)
- [Apple: DeviceActivityReport and its isolation](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport)
- [Apple: Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [Apple: FamilyActivityData availability](https://developer.apple.com/documentation/familycontrols/familyactivitydata)
- [Slack: conversations.history](https://docs.slack.dev/reference/methods/conversations.history/)
- [Google: Gmail authorization scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [Apple: iCloud Mail server settings](https://support.apple.com/en-mt/102525)
