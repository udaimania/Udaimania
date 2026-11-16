import SwiftUI
import CaptureCore

@MainActor
final class LabStore: ObservableObject {
    @Published var rules: [MatchRule] = []
    @Published var trials: [CaptureTrial] = []
    @Published var serviceEvents: [ServiceEvent] = []
    @Published var serviceProbes: [ServiceEnvelope] = []
    @Published var retainWorkExcerpts = false
    @Published var error: String?
    @Published var lastExport: URL?
    private let file: URL

    struct Saved: Codable {
        var schemaVersion = 1
        var rules: [MatchRule]
        var trials: [CaptureTrial]
        var serviceEvents: [ServiceEvent]
        var serviceProbes: [ServiceEnvelope]?
        var retainWorkExcerpts: Bool
    }

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CaptureLab", isDirectory: true)
        file = directory.appendingPathComponent("lab.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            if FileManager.default.fileExists(atPath: file.path) {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: file))
                rules = saved.rules; trials = saved.trials; serviceEvents = saved.serviceEvents
                serviceProbes = saved.serviceProbes ?? []
                retainWorkExcerpts = saved.retainWorkExcerpts
                for index in trials.indices where trials[index].endedAt == nil {
                    trials[index].endedAt = trials[index].samples.last?.at ?? trials[index].startedAt
                    trials[index].endedUptime = trials[index].samples.last?.uptime ?? trials[index].startedUptime
                    trials[index].endReason = "App exited; actual end time unknown. Summary stops at last sample."
                }
            }
        } catch { self.error = "Local storage: \(error.localizedDescription)" }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(Saved(rules: rules, trials: trials, serviceEvents: serviceEvents,
                                                       serviceProbes: serviceProbes,
                                                       retainWorkExcerpts: retainWorkExcerpts))
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { self.error = "Save failed: \(error.localizedDescription)" }
    }

    func begin(name: String) -> UUID {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = UIDevice.current.batteryLevel
        let trial = CaptureTrial(name: name.isEmpty ? "Untitled trial" : name, startedAt: Date(),
                                 startedUptime: ProcessInfo.processInfo.systemUptime, rules: rules,
                                 batteryStart: battery < 0 ? nil : battery)
        trials.insert(trial, at: 0); save(); return trial.id
    }

    func append(_ sample: CaptureSample, to id: UUID) {
        guard let i = trials.firstIndex(where: { $0.id == id }), trials[i].endedAt == nil else { return }
        trials[i].samples.append(sample); save()
    }

    func lifecycle(_ name: String, trial id: UUID?) {
        guard let id, let i = trials.firstIndex(where: { $0.id == id }) else { return }
        trials[i].lifecycle.append(.init(at: Date(), uptime: ProcessInfo.processInfo.systemUptime, name: name)); save()
    }

    func finish(_ id: UUID, reason: String) {
        guard let i = trials.firstIndex(where: { $0.id == id }), trials[i].endedAt == nil else { return }
        trials[i].endedAt = Date(); trials[i].endedUptime = ProcessInfo.processInfo.systemUptime
        trials[i].endReason = reason
        let battery = UIDevice.current.batteryLevel
        trials[i].batteryEnd = battery < 0 ? nil : battery
        save()
    }

    func setReference(_ id: UUID, seconds: Double, kind: WorkClass, note: String) {
        guard seconds.isFinite, seconds > 0, let i = trials.firstIndex(where: { $0.id == id }) else { return }
        trials[i].referenceSeconds = seconds; trials[i].referenceClass = kind
        trials[i].referenceNote = note; save()
    }

    func importServiceData(_ url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 5_000_000 else { throw ImportError.tooLarge }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(ServiceEnvelope.self, from: Data(contentsOf: url))
            guard envelope.schemaVersion == 1, envelope.events.count <= 2000 else { throw ImportError.invalidSchema }
            serviceEvents = EventMerge.merge(serviceEvents, envelope.events)
            if !serviceProbes.contains(where: { $0.provider == envelope.provider && $0.collectedAt == envelope.collectedAt }) {
                serviceProbes.append(envelope)
            }
            save()
        } catch { self.error = "Import failed: \(error.localizedDescription)" }
    }

    func export() {
        struct Export: Encodable {
            var schemaVersion = 1
            var exportedAt = Date()
            var device: String
            var os: String
            var trials: [CaptureTrial]
            var summaries: [DurationSummary]
            var referenceComparisons: [String: ReferenceComparison]
            var serviceEvents: [ServiceEvent]
            var serviceProbes: [ServiceEnvelope]
            var limitations = [
                "Classified durations are estimates from adjacent OCR samples, not attention measurements.",
                "Missing, blank, idle and ambiguous intervals remain unclassified.",
                "Service events do not establish device or duration.",
                "Screen Time report data is deliberately not exported from its isolated extension.",
                "Battery readings are coarse, charging-sensitive observations; this is not an energy benchmark."
            ]
        }
        do {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let export = Export(device: UIDevice.current.model, os: UIDevice.current.systemVersion,
                                trials: trials, summaries: trials.map { DurationEstimator.summarize($0, nowUptime: ProcessInfo.processInfo.systemUptime) },
                                referenceComparisons: Dictionary(uniqueKeysWithValues: trials.compactMap { trial in
                                    ReferenceComparison.compare(trial).map { (trial.id.uuidString, $0) }
                                }), serviceEvents: serviceEvents, serviceProbes: serviceProbes)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Udaimania-CaptureLab-\(UUID().uuidString.prefix(8)).json")
            try encoder.encode(export).write(to: url, options: [.atomic, .completeFileProtection])
            lastExport = url
        } catch { self.error = "Export failed: \(error.localizedDescription)" }
    }

    enum ImportError: LocalizedError {
        case tooLarge, invalidSchema
        var errorDescription: String? { "Use a Capture Lab service-probe JSON file under 5 MB with schemaVersion 1." }
    }
}
