# Capture Lab verification — 15 November 2026

The prototype is installed and has completed one **synthetic** cross-app trial on a physical iPhone. Screen-text matching worked, but the current conservative estimator substantially undercounted static screens. This is not a successful reliability test for continuous work-time measurement. The user's actual work accounts were excluded.

## Environment and checks

- Xcode 27.2 (27B52); physical iPhone 15 Pro Max running iOS 27.2 (24B119).
- Basic app signed with the user's Personal Team, installed, trusted and launched. Synthetic Test Scenes separately signed, installed and launched.
- Basic simulator and device builds passed. Screen Time variant compiled for simulator and unsigned device; final simulator build passed after source updates.
- Family Controls signing was explicitly rejected: Personal development teams do not support the Family Controls (Development) capability. The report extension therefore has **not** been run on this phone.
- 13 Swift core tests passed. 11 Python tests passed, covering mocked read-only service behavior and synthetic-reference analysis. Mocked API tests do not establish live authentication or API results.
- Capture/Sources/Results screens were exercised on the phone. Synthetic rules loaded, capture started through Apple's picker, capture stopped, and JSON export preparation succeeded. No report was shared to an external recipient.
- The final UI uses the system blue accent after the first device inspection showed poor contrast from the original fixed brown tint in dark mode.

## Actual device trial

The fixture requested five 30-second stages. Its observed monotonic stage durations were approximately 31–32 seconds each, so those recorded intervals are used as the reference rather than assuming the requested timing. Reference timestamps record programmatic transitions; app activation and rendering latency can shift visible boundaries. A second stream from Xcode Device Hub was used to observe setup and completion, so this is a development environment, not an uninstrumented energy test.

| Synthetic screen | Reference interval | Correct-class estimated time | Unclassified time | Absolute duration error |
| --- | ---: | ---: | ---: | ---: |
| Static Slack reading | 31.45 s | 10.92 s | 20.53 s | 65.3% |
| Changing Slack screen | 31.97 s | 31.04 s | 0.93 s | 2.9% |
| Static work email | 32.01 s | 10.73 s | 21.27 s | 66.5% |
| Personal email negative control | 31.99 s | No work estimated | 31.99 s | Not applicable |
| Static non-work control | 31.99 s | 11.55 s | 20.44 s | 63.9% |

The personal-email and non-work controls produced zero estimated false-work seconds in this run. This small synthetic sample does not establish a real-world false-positive rate. No raw OCR excerpts were retained, no images/video were saved, and no real work messages were read or sent.

The complete capture lasted 256.40 seconds including setup and return to the lab. It logged 83 samples. Mean OCR processing time was 276 ms, maximum 467 ms; the longest observed callback gap was 17.84 seconds. Battery readings stayed at 100% while connected to USB and are not useful as an energy result. Capture ended with the recorded reason `Stopped by user`.

The changing screen generated enough matching samples for a close duration estimate. Static-screen callbacks were sparse enough to exceed the six-second interpolation limit. The estimator left these gaps unknown, as intended, instead of filling them with assumed work. Extending the limit might increase apparent coverage but could also count hidden app switches or interruptions; this trial does not justify doing that.

## Evidence and reproduction

- Local raw lab record: `build/capturelab-current.json` (ignored by Git).
- Independent fixture log: `build/capturelab-reference/reference-7E51B4CD-F78D-4741-9C47-81FB08C7B2A3.json` (ignored).
- Derived analysis: `build/capturelab-synthetic-analysis.json` (ignored).
- Trial ID: `01BCEB84-A42F-4868-A1C1-CF977D379A0B`. The first build retained the default UI name `Slack • reading only`; the actual test was the five-stage synthetic sequence above. Later builds use the neutral default `Device trial`.
- Build/test logs: `build/capturelab-*.log`.

Reproduce using the account-free procedure in `README.md`. Compare logs from the same device boot with `scripts/analyze_synthetic_trial.py`. Re-run at least three times before assessing consistency. The initial run failed the proposed static-screen coverage/timing gates in the test protocol.

## Still unverified

Real Slack, Gmail and Apple Mail screen behavior; thread/account marker persistence; actual service-event availability and delays; message-text transcription accuracy; lock/unlock and interrupted sessions; landscape orientation; notification redaction; offline behavior; sustained thermal/battery cost; five-minute automatic-stop behavior; report-extension runtime and reporting delay; 24-hour coverage and distribution approval.

Read-only Slack, Gmail and iCloud probe implementations exist, but no authenticated probe ran. Gmail's connected profile check returned a reauthentication requirement before any message read. Following the user's direction, work-account connections were not pursued. The iPhone app currently imports probe output; it does not contain production service login or synchronization.

Next engineering decision: obtain an eligible development team for the isolated Screen Time comparison, or evaluate another explicitly user-started measurement approach. Do not present the current OCR estimate as reliable static reading time or enable continuous team reporting from these results.
