import SwiftUI
import UniformTypeIdentifiers
import CaptureCore

@main
struct CaptureLabApp: App {
    @StateObject private var store = LabStore()
    @StateObject private var engine = CaptureEngine()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TabView {
                CaptureView().tabItem { Label("Capture", systemImage: "record.circle") }
                SourcesView().tabItem { Label("Sources", systemImage: "line.3.horizontal.decrease.circle") }
                ResultsView().tabItem { Label("Results", systemImage: "chart.bar.xaxis") }
                UsageView().tabItem { Label("Usage", systemImage: "hourglass") }
            }
            .tint(.blue)
            .environmentObject(store).environmentObject(engine)
            .onChange(of: phase) { _, value in engine.setAppActive(value == .active) }
            .alert("Capture Lab", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

struct CaptureView: View {
    @EnvironmentObject var store: LabStore
    @EnvironmentObject var engine: CaptureEngine
    @State private var name = "Device trial"
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Udaimania Capture Lab", systemImage: "viewfinder")
                        .font(.title2.weight(.semibold))
                    Text("Find out what the iPhone can actually observe.")
                        .foregroundStyle(.secondary)
                    LabeledContent("Environment", value: engine.simulator ? "Simulator • UI only" : "iPhone • iOS \(UIDevice.current.systemVersion)")
                    Text(engine.status).font(.callout).accessibilityIdentifier("capture-status")
                }
                Section("Run a controlled trial") {
                    TextField("Trial name", text: $name).accessibilityIdentifier("trial-name")
                    Text("Start capture, switch to Slack or a work mailbox, then return and stop. Use a separate stopwatch and note exactly what you did.")
                    if engine.isRecording || engine.isStarting {
                        Button(role: .destructive) { Task { await engine.stop() } } label: {
                            Label("Stop capture", systemImage: "stop.circle.fill")
                        }.accessibilityIdentifier("stop-capture")
                    } else {
                        Button { confirm = true } label: { Label("Start device trial", systemImage: "record.circle") }
                            .disabled(engine.simulator).accessibilityIdentifier("start-capture")
                    }
                    if store.rules.isEmpty {
                        Text("Add visible work markers in Sources first. With no rules, captured intervals remain unclassified.")
                            .foregroundStyle(.orange)
                    }
                    Text("Five-minute session limit. The system recording control can stop the session at any time.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let id = engine.activeTrialID, let trial = store.trials.first(where: { $0.id == id }) {
                    Section("Live measurements") {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            SummaryRows(summary: DurationEstimator.summarize(trial, nowUptime: ProcessInfo.processInfo.systemUptime))
                        }
                    }
                }
                Section("What is captured") {
                    Text("The system shares the full display. iOS does not provide the Mac’s app exclusion controls. Frames from other apps can reach this process during a session.")
                    Text("Images are processed locally and discarded. No microphone, video file, or automatic upload. Text is discarded unless you explicitly enable matched work excerpts in Sources.")
                    Text("Screen text is only a classification hint. Missing callbacks, ambiguous text, and locked or blank screens stay unclassified.")
                }
                Section("Suggested device tests") {
                    ForEach([
                        "1 · Slack work channel: read for 60 seconds without sending.",
                        "2 · Slack: compose and send a short test reply; compare visible text with the sent event.",
                        "3 · Gmail work account, then personal account: check false work matches.",
                        "4 · iCloud Mail: selected work mailbox, then a mixed inbox.",
                        "5 · Switch to a non-work app and lock the phone for 30 seconds.",
                        "6 · Repeat while offline; inspect gaps, rotation, heat and battery."
                    ], id: \.self) { Text($0).font(.callout) }
                    Text("Use your own test messages. Capture Lab never sends a message or email.").font(.footnote)
                }
            }
            .navigationTitle("Capture")
            .confirmationDialog("Start a full-display test?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Open system capture picker") { engine.start(name: name, store: store) }
            } message: {
                Text("This is full-screen capture, not Slack/Mail-only capture. Other apps’ frames may be processed locally. Close private material and stop the session when your test is complete.")
            }
        }
    }
}

struct SourcesView: View {
    @EnvironmentObject var store: LabStore
    @EnvironmentObject var engine: CaptureEngine
    @State private var kind: WorkClass = .slack
    @State private var cue = ""
    @State private var context = ""
    @State private var importing = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Visible work markers") {
                    Text("A rule needs BOTH a visible app cue and a work-specific marker. Neither is authenticated app/account identity. Configure Gmail and iCloud separately, even inside the same mail app.")
                    if store.rules.isEmpty {
                        Button("Use synthetic test rules") {
                            store.rules = [
                                .init(classification: .slack, appCue: "Udaimania Test Scenes", context: "SLACK-WORK-TEST"),
                                .init(classification: .workMail, appCue: "Udaimania Test Scenes", context: "MAIL-WORK-TEST"),
                                .init(classification: .nonWork, appCue: "Udaimania Test Scenes", context: "OTHER-USE-TEST")
                            ]; store.save()
                        }
                        Text("For the separate Udaimania Scenes test app only. Uses invented messages and no connected accounts.").font(.footnote)
                    }
                    ForEach(store.rules) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.classification.title).font(.headline)
                            Text("\(rule.appCue) + \(rule.context)").font(.callout)
                        }
                    }
                    .onDelete { offsets in store.rules.remove(atOffsets: offsets); store.save() }
                    Picker("Class", selection: $kind) {
                        ForEach([WorkClass.slack, .workMail, .nonWork], id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("App cue, e.g. Slack or Inbox", text: $cue)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("rule-app-cue")
                    TextField("Work channel, mailbox, or account marker", text: $context)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("rule-context")
                    Button("Add rule") {
                        store.rules.append(.init(classification: kind,
                                                 appCue: cue.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 context: context.trimmingCharacters(in: .whitespacesAndNewlines)))
                        cue = ""; context = ""; store.save()
                    }.disabled(cue.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 ||
                               context.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                        .accessibilityIdentifier("add-rule")
                }.disabled(engine.isRecording || engine.isStarting)
                Section("Local evidence") {
                    Toggle("Keep matched work text excerpts", isOn: $store.retainWorkExcerpts)
                        .onChange(of: store.retainWorkExcerpts) { _, _ in store.save() }
                        .disabled(engine.isRecording || engine.isStarting)
                    Text("Off by default. If enabled, up to 1,200 characters of a matching frame are kept locally and included in an explicit export. A false match could include non-work text.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Service evidence: separate measurement") {
                    Text("Import read-only probe output from Slack, Gmail, or iCloud Mail. The Mac probe script keeps credentials out of this app and out of reports.")
                    Button("Import service-probe JSON") { importing = true }.accessibilityIdentifier("import-service")
                    Text("A message event proves an event occurred. It does not establish phone use, reading time, or continuous work between messages.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sources")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): store.importServiceData(url)
                case .failure(let error): store.error = error.localizedDescription
                }
            }
        }
    }
}

struct SummaryRows: View {
    let summary: DurationSummary
    var body: some View {
        LabeledContent("Session elapsed", value: seconds(summary.elapsedSeconds))
        LabeledContent("Slack • estimated", value: seconds(summary.estimatedSlackSeconds))
        LabeledContent("Work email • estimated", value: seconds(summary.estimatedMailSeconds))
        LabeledContent("Other use • estimated", value: seconds(summary.estimatedNonWorkSeconds))
        LabeledContent("Unclassified", value: seconds(summary.unclassifiedSeconds))
        LabeledContent("Classified coverage", value: String(format: "%.0f%%", summary.estimatedCoverageFraction * 100))
        LabeledContent("Longest sample gap", value: seconds(summary.maximumSampleGapSeconds))
        LabeledContent("Samples / readable", value: "\(summary.sampleCount) / \(summary.readableSampleCount)")
        LabeledContent("Mean OCR processing", value: String(format: "%.0f ms", summary.meanProcessingMilliseconds))
    }
}
private func seconds(_ value: Double) -> String { String(format: "%.1f s", value) }

struct ResultsView: View {
    @EnvironmentObject var store: LabStore
    var body: some View {
        NavigationStack {
            List {
                Section("Capture trials") {
                    if store.trials.isEmpty {
                        ContentUnavailableView("No device trials yet", systemImage: "waveform.path.ecg",
                                               description: Text("Simulator checks are not evidence of Slack or email capture."))
                    }
                    ForEach(store.trials) { trial in
                        NavigationLink { TrialDetail(id: trial.id) } label: {
                            VStack(alignment: .leading) {
                                Text(trial.name)
                                Text(trial.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(trial.endReason ?? "Running").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Imported service evidence") {
                    if store.serviceEvents.isEmpty { Text("No authenticated service probe has been imported.").foregroundStyle(.secondary) }
                    ForEach(store.serviceEvents, id: \.identity) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.description)
                            Text("\(event.source) • \(event.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(event.authorshipEvidence ?? (event.userAuthored ? "Service authorship signal" : "Authorship unverified")) • duration unknown • device unknown")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Array(store.serviceProbes.enumerated()), id: \.offset) { _, probe in
                        DisclosureGroup("\(probe.provider) probe limits") {
                            Text(probe.collectedAt.formatted()).font(.caption)
                            ForEach(probe.limitations, id: \.self) { Text($0).font(.caption) }
                        }
                    }
                }
                Section("Export") {
                    Text("Exports include trial measurements, rule markers, imported event metadata, and any work excerpts you chose to retain. Nothing is sent automatically.")
                    Button("Prepare JSON report") { store.export() }.accessibilityIdentifier("prepare-export")
                    if let url = store.lastExport {
                        ShareLink("Share prepared report", item: url)
                    }
                }
            }.navigationTitle("Results")
        }
    }
}

struct TrialDetail: View {
    @EnvironmentObject var store: LabStore
    let id: UUID
    @State private var reference = ""
    @State private var referenceKind: WorkClass = .slack
    @State private var note = ""
    var body: some View {
        Form {
            if let trial = store.trials.first(where: { $0.id == id }) {
                Section("Measured and estimated") {
                    SummaryRows(summary: DurationEstimator.summarize(trial, nowUptime: ProcessInfo.processInfo.systemUptime))
                    Text("Session elapsed is measured. Work durations interpolate only matching readable samples at most six seconds apart. Reading attention is not measured.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Independent reference") {
                    if let existing = trial.referenceSeconds {
                        LabeledContent("Operator-observed duration", value: seconds(existing))
                        Text(trial.referenceNote ?? "")
                        if let comparison = ReferenceComparison.compare(trial) {
                            LabeledContent("Compared activity", value: comparison.classification.title)
                            LabeledContent("Estimate minus reference", value: String(format: "%+.1f s", comparison.signedErrorSeconds))
                            LabeledContent("Absolute timing error", value: String(format: "%.1f%%", comparison.absoluteErrorFraction * 100))
                            Text("This compares one activity’s total duration, not whether every interval was classified correctly. Test personal-account false matches separately.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Stopwatch seconds", text: $reference).keyboardType(.decimalPad)
                    Picker("Activity tested", selection: $referenceKind) {
                        ForEach([WorkClass.slack, .workMail, .nonWork], id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("What actually happened, including interruptions", text: $note, axis: .vertical)
                    Button("Save reference") {
                        if let value = Double(reference) { store.setReference(id, seconds: value, kind: referenceKind, note: note) }
                    }.disabled(trial.endedAt == nil || Double(reference).map { $0 <= 0 || !$0.isFinite } ?? true)
                }
                Section("Conditions") {
                    Text(trial.endReason ?? "Running")
                    if let start = trial.batteryStart, let end = trial.batteryEnd {
                        LabeledContent("Battery start → end", value: "\(Int(start * 100))% → \(Int(end * 100))%")
                        Text("Coarse battery readings; charging and other apps affect this.").font(.footnote)
                    }
                    ForEach(Array(trial.lifecycle.enumerated()), id: \.offset) { _, item in
                        Text("\(item.at.formatted(date: .omitted, time: .standard)) · \(item.name)").font(.caption)
                    }
                }
                Section("Most recent samples") {
                    ForEach(trial.samples.suffix(30).reversed()) { sample in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(sample.at.formatted(date: .omitted, time: .standard)) · \(sample.classification.kind.title)")
                            Text("\(sample.condition.rawValue) · \(sample.recognizedCharacters) recognized characters")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(sample.classification.reason).font(.caption).foregroundStyle(.secondary)
                            if let excerpt = sample.excerpt { Text(excerpt).font(.caption).textSelection(.enabled) }
                        }
                    }
                }
            }
        }.navigationTitle("Trial detail")
    }
}
