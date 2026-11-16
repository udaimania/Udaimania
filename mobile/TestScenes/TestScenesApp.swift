import SwiftUI

// A separate, entirely synthetic foreground app. Its log supplies an independent
// monotonic reference; it has no Slack, Google, Apple Mail or network integration.
@main
struct TestScenesApp: App {
    @StateObject private var run = SceneRun()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TestSceneView().environmentObject(run)
                .onChange(of: phase) { _, phase in run.setActive(phase == .active) }
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("--run-trial") { run.start() }
                }
        }
    }
}

struct FixtureStep {
    var title: String
    var marker: String
    var classification: String
    var body: String
    var dynamic = false
}

@MainActor
final class SceneRun: ObservableObject {
    @Published var index: Int?
    @Published var finished = false
    @Published var error: String?
    private var task: Task<Void, Never>?
    private var active = true
    private var events: [ReferenceEvent] = []
    private var id = UUID()
    struct ReferenceEvent: Codable {
        var uptime: Double
        var at: Date
        var event: String
        var classification: String
        var step: Int?
    }
    let steps = [
        FixtureStep(title: "Slack · static reading", marker: "SLACK-WORK-TEST", classification: "slack",
                    body: "# prototype-test\n\nAlex: The demo uses invented content only.\n\nSam: Please review the launch checklist.\n\nAlex: Copy, layout and accessibility checks are ready.\n\nThis screen stays unchanged for 30 seconds."),
        FixtureStep(title: "Slack · changing screen", marker: "SLACK-WORK-TEST", classification: "slack",
                    body: "# prototype-test\n\nAlex: Here is the next synthetic update.\n\nSam: We are checking callback delivery when pixels change.\n\nNo real message is sent.", dynamic: true),
        FixtureStep(title: "Work email · synthetic inbox", marker: "MAIL-WORK-TEST", classification: "workMail",
                    body: "demo@work.example\n\nFrom: Alex Example\nSubject: Prototype review\n\nPlease review the mock design and timeline.\n\nThis is synthetic content, not Gmail or iCloud Mail."),
        FixtureStep(title: "Personal email · negative control", marker: "MAIL-PERSONAL-TEST", classification: "unknown",
                    body: "demo@personal.example\n\nFrom: Taylor Example\nSubject: Weekend picnic\n\nMeet at the park after lunch.\n\nNo work marker is present. Expected result: unclassified."),
        FixtureStep(title: "Other use · positive control", marker: "OTHER-USE-TEST", classification: "nonWork",
                    body: "A synthetic recipe\n\nCombine flour, water and salt.\nRest the dough before baking.\n\nThis explicit test rule should classify other phone use.")
    ]
    var step: FixtureStep? { index.map { steps[$0] } }
    func start() {
        guard task == nil else { return }
        events = []; id = UUID(); finished = false
        task = Task {
            for next in steps.indices {
                guard !Task.isCancelled else { return }
                index = next; record("step-start")
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
            record("finished"); index = nil; finished = true; task = nil
        }
    }
    func setActive(_ value: Bool) {
        active = value
        guard index != nil else { return }
        record(value ? "foreground" : "background")
        if !value {
            task?.cancel(); task = nil; record("interrupted"); index = nil
        }
    }
    private func record(_ event: String) {
        events.append(.init(uptime: ProcessInfo.processInfo.systemUptime, at: Date(), event: event,
                            classification: active ? (step?.classification ?? "unknown") : "unknown", step: index))
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(events).write(to: directory.appendingPathComponent("reference-\(id.uuidString).json"), options: .atomic)
        } catch { self.error = error.localizedDescription }
    }
}

struct TestSceneView: View {
    @EnvironmentObject var run: SceneRun
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Udaimania Test Scenes").font(.headline)
                Text("SYNTHETIC CONTENT ONLY").font(.caption).foregroundStyle(.secondary)
                if let step = run.step {
                    Text(step.title).font(.largeTitle.bold())
                    Text(step.marker).font(.title3.monospaced()).bold()
                    Text(step.body).font(.body).lineSpacing(7)
                    if step.dynamic {
                        TimelineView(.periodic(from: .now, by: 1)) { tick in
                            Text("Changing pixels: \(tick.date.formatted(date: .omitted, time: .standard))").font(.caption.monospaced())
                        }
                    }
                    Text("Step \((run.index ?? 0) + 1) of 5 · automatic 30-second stages")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(run.finished ? "Reference run finished" : "Cross-app capture reference").font(.largeTitle.bold())
                    Text("Five synthetic screens run for 30 seconds each: static Slack, changing Slack, work email, personal email, and other use. This tests the capture pipeline, not the real services.")
                    Text("Start Udaimania Lab capture first, then open this app. Returning to another app interrupts the reference run.")
                    Button(run.finished ? "Run again" : "Begin 150-second reference") { run.start() }.buttonStyle(.borderedProminent)
                    if run.finished { Text("Return to Udaimania Lab and stop capture. The independent reference log is saved locally.") }
                }
                if let error = run.error { Text(error).foregroundStyle(.red) }
            }.padding(24)
        }
    }
}
