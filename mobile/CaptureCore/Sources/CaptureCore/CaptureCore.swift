import Foundation

public enum WorkClass: String, Codable, Sendable, CaseIterable {
    case slack, workMail, nonWork, unknown
    public var title: String {
        switch self {
        case .slack: "Slack work"
        case .workMail: "Work email"
        case .nonWork: "Other phone use"
        case .unknown: "Unclassified"
        }
    }
}

public struct MatchRule: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var classification: WorkClass
    public var appCue: String
    public var context: String
    public init(id: UUID = UUID(), classification: WorkClass, appCue: String, context: String) {
        self.id = id; self.classification = classification; self.appCue = appCue; self.context = context
    }
}

public struct Classification: Codable, Sendable, Equatable {
    public var kind: WorkClass
    public var ruleIDs: [UUID]
    public var reason: String
    public init(kind: WorkClass, ruleIDs: [UUID] = [], reason: String) {
        self.kind = kind; self.ruleIDs = ruleIDs; self.reason = reason
    }
}

public enum Classifier {
    /// Both a visible app cue and a work-specific marker must match. This remains an OCR
    /// hypothesis, not authenticated foreground-app or mailbox identity.
    public static func classify(_ text: String, rules: [MatchRule]) -> Classification {
        let matches = rules.filter {
            $0.classification != .unknown && contains(text, marker: $0.appCue) && contains(text, marker: $0.context)
        }
        let kinds = Set(matches.map(\.classification))
        guard kinds.count == 1, let kind = kinds.first else {
            return Classification(kind: .unknown, reason: kinds.isEmpty ? "No complete visible rule match" : "Conflicting visible rule matches")
        }
        return Classification(kind: kind, ruleIDs: matches.map(\.id), reason: "Visible text matches; app/account identity unverified")
    }

    private static func contains(_ text: String, marker: String) -> Bool {
        let marker = marker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard marker.count >= 3 else { return false }
        // Do not match example.com inside notexample.com or user@example.com inside another address.
        let boundary = #"[\p{L}\p{N}_@.\-]"#
        let pattern = "(?<!" + boundary + ")" + NSRegularExpression.escapedPattern(for: marker) + "(?!" + boundary + ")"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

public enum FrameCondition: String, Codable, Sendable {
    case readable, idle, blank, suspended, stopped, failed, ownApp
}

public struct CaptureSample: Codable, Identifiable, Sendable {
    public var id: UUID
    public var at: Date
    public var uptime: Double
    public var condition: FrameCondition
    public var classification: Classification
    public var recognizedCharacters: Int
    public var processingMilliseconds: Double
    public var excerpt: String?
    public init(id: UUID = UUID(), at: Date, uptime: Double, condition: FrameCondition,
                classification: Classification, recognizedCharacters: Int = 0,
                processingMilliseconds: Double = 0, excerpt: String? = nil) {
        self.id = id; self.at = at; self.uptime = uptime; self.condition = condition
        self.classification = classification; self.recognizedCharacters = recognizedCharacters
        self.processingMilliseconds = processingMilliseconds; self.excerpt = excerpt
    }
}

public struct LifecycleEvent: Codable, Sendable {
    public var at: Date
    public var uptime: Double
    public var name: String
    public init(at: Date, uptime: Double, name: String) { self.at = at; self.uptime = uptime; self.name = name }
}

public struct CaptureTrial: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var startedAt: Date
    public var startedUptime: Double
    public var endedAt: Date?
    public var endedUptime: Double?
    public var endReason: String?
    public var rules: [MatchRule]
    public var samples: [CaptureSample] = []
    public var lifecycle: [LifecycleEvent] = []
    public var batteryStart: Float?
    public var batteryEnd: Float?
    public var referenceSeconds: Double?
    public var referenceClass: WorkClass?
    public var referenceNote: String?
    public init(name: String, startedAt: Date, startedUptime: Double, rules: [MatchRule], batteryStart: Float?) {
        self.name = name; self.startedAt = startedAt; self.startedUptime = startedUptime
        self.rules = rules; self.batteryStart = batteryStart
    }
}

public struct DurationSummary: Codable, Sendable, Equatable {
    public var elapsedSeconds: Double
    public var estimatedSlackSeconds: Double
    public var estimatedMailSeconds: Double
    public var estimatedNonWorkSeconds: Double
    public var unclassifiedSeconds: Double
    public var estimatedCoverageFraction: Double
    public var maximumSampleGapSeconds: Double
    public var sampleCount: Int
    public var readableSampleCount: Int
    public var meanProcessingMilliseconds: Double
}

public struct ReferenceComparison: Codable, Sendable, Equatable {
    public var classification: WorkClass
    public var referenceSeconds: Double
    public var estimatedSeconds: Double
    public var signedErrorSeconds: Double
    public var absoluteErrorSeconds: Double
    public var absoluteErrorFraction: Double

    public static func compare(_ trial: CaptureTrial) -> ReferenceComparison? {
        guard trial.endedUptime != nil, let reference = trial.referenceSeconds,
              reference.isFinite, reference > 0, let kind = trial.referenceClass, kind != .unknown else { return nil }
        let summary = DurationEstimator.summarize(trial)
        let estimate: Double
        switch kind {
        case .slack: estimate = summary.estimatedSlackSeconds
        case .workMail: estimate = summary.estimatedMailSeconds
        case .nonWork: estimate = summary.estimatedNonWorkSeconds
        case .unknown: return nil
        }
        let error = estimate - reference
        return .init(classification: kind, referenceSeconds: reference, estimatedSeconds: estimate,
                     signedErrorSeconds: error, absoluteErrorSeconds: abs(error), absoluteErrorFraction: abs(error) / reference)
    }
}

public enum DurationEstimator {
    /// Only bridge adjacent readable samples of the SAME class within maxGap.
    /// No forward fill across blank/idle/unknown frames or missing callbacks.
    /// All classified duration is explicitly an estimate, not attention measurement.
    public static func summarize(_ trial: CaptureTrial, nowUptime: Double? = nil, maxGap: Double = 6) -> DurationSummary {
        let end = max(trial.startedUptime, trial.endedUptime ?? nowUptime ?? trial.startedUptime)
        let elapsed = end - trial.startedUptime
        let samples = trial.samples.filter {
            $0.uptime.isFinite && $0.uptime >= trial.startedUptime && $0.uptime <= end
        }.sorted { $0.uptime < $1.uptime }
        var seconds: [WorkClass: Double] = [:]
        var maxObservedGap = samples.first.map { $0.uptime - trial.startedUptime } ?? elapsed
        for (left, right) in zip(samples, samples.dropFirst()) {
            let dt = right.uptime - left.uptime
            maxObservedGap = max(maxObservedGap, dt)
            guard dt > 0, dt <= maxGap, left.condition == .readable, right.condition == .readable,
                  left.classification.kind != .unknown, left.classification.kind == right.classification.kind else { continue }
            seconds[left.classification.kind, default: 0] += dt
        }
        if let last = samples.last { maxObservedGap = max(maxObservedGap, end - last.uptime) }
        let classified = seconds.values.reduce(0, +)
        let readable = samples.filter { $0.condition == .readable }
        return DurationSummary(elapsedSeconds: elapsed,
            estimatedSlackSeconds: seconds[.slack, default: 0],
            estimatedMailSeconds: seconds[.workMail, default: 0],
            estimatedNonWorkSeconds: seconds[.nonWork, default: 0],
            unclassifiedSeconds: max(0, elapsed - classified),
            estimatedCoverageFraction: elapsed > 0 ? classified / elapsed : 0,
            maximumSampleGapSeconds: maxObservedGap, sampleCount: samples.count, readableSampleCount: readable.count,
            meanProcessingMilliseconds: readable.isEmpty ? 0 : readable.map(\.processingMilliseconds).reduce(0, +) / Double(readable.count))
    }
}

public struct ServiceEvent: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var source: String
    public var timestamp: Date
    public var description: String
    public var userAuthored: Bool
    public var authorshipEvidence: String?
    public var identity: String { source + ":" + id }
    /// The service does not establish reading/writing time or the originating device.
    public var durationSeconds: Double? { nil }
    public var device: String { "unknown" }
    public init(id: String, source: String, timestamp: Date, description: String, userAuthored: Bool, authorshipEvidence: String? = nil) {
        self.id = id; self.source = source; self.timestamp = timestamp
        self.description = description; self.userAuthored = userAuthored
        self.authorshipEvidence = authorshipEvidence
    }
}

public struct ServiceEnvelope: Codable, Sendable {
    public var schemaVersion: Int
    public var provider: String
    public var collectedAt: Date
    public var events: [ServiceEvent]
    public var limitations: [String]
    public init(schemaVersion: Int = 1, provider: String, collectedAt: Date, events: [ServiceEvent], limitations: [String]) {
        self.schemaVersion = schemaVersion; self.provider = provider; self.collectedAt = collectedAt
        self.events = events; self.limitations = limitations
    }
}

public enum EventMerge {
    public static func merge(_ existing: [ServiceEvent], _ incoming: [ServiceEvent]) -> [ServiceEvent] {
        var keyed = Dictionary(existing.map { ($0.source + ":" + $0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        for event in incoming { keyed[event.source + ":" + event.id] = event }
        return keyed.values.sorted { $0.timestamp > $1.timestamp }
    }
}
