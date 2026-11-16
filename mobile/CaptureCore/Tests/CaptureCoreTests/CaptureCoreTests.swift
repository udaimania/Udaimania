import Foundation
import XCTest
@testable import CaptureCore

final class CaptureCoreTests: XCTestCase {
    private let rule = MatchRule(classification: .workMail, appCue: "Inbox", context: "nick@work.example")
    private func sample(_ time: Double, _ kind: WorkClass = .slack, condition: FrameCondition = .readable) -> CaptureSample {
        CaptureSample(at: Date(timeIntervalSince1970: time), uptime: time, condition: condition,
                      classification: Classification(kind: kind, reason: "fixture"))
    }
    private func trial(_ samples: [CaptureSample], end: Double = 20) -> CaptureTrial {
        var trial = CaptureTrial(name: "fixture", startedAt: .distantPast, startedUptime: 0, rules: [], batteryStart: nil)
        trial.samples = samples; trial.endedUptime = end
        return trial
    }
    func testMailRequiresBothAppCueAndAccountContext() {
        XCTAssertEqual(Classifier.classify("Inbox\nNICK@WORK.EXAMPLE\nPricing", rules: [rule]).kind, .workMail)
        XCTAssertEqual(Classifier.classify("Inbox\nnick@personal.example", rules: [rule]).kind, .unknown)
        XCTAssertEqual(Classifier.classify("nick@work.example", rules: [rule]).kind, .unknown)
    }
    func testMarkersDoNotMatchEmbeddedEmailOrDomain() {
        XCTAssertEqual(Classifier.classify("Inbox othernick@work.example", rules: [rule]).kind, .unknown)
        let domain = MatchRule(classification: .workMail, appCue: "Inbox", context: "work.example")
        XCTAssertEqual(Classifier.classify("Inbox notwork.example", rules: [domain]).kind, .unknown)
    }
    func testEmptyAndTrivialRulesCannotClassifyEverything() {
        XCTAssertEqual(Classifier.classify("Inbox", rules: [.init(classification: .slack, appCue: "", context: "")]).kind, .unknown)
    }
    func testConflictingSourcesRemainUnknown() {
        let slack = MatchRule(classification: .slack, appCue: "Slack", context: "project-launch")
        XCTAssertEqual(Classifier.classify("Slack project-launch Inbox nick@work.example", rules: [rule, slack]).kind, .unknown)
    }
    func testOnlyAdjacentObservedIntervalsAreEstimated() {
        let result = DurationEstimator.summarize(trial([sample(2), sample(4), sample(6)]))
        XCTAssertEqual(result.estimatedSlackSeconds, 4)
        XCTAssertEqual(result.unclassifiedSeconds, 16)
        XCTAssertEqual(result.maximumSampleGapSeconds, 14)
    }
    func testLongGapsAndLockedScreensNeverBecomeWork() {
        let result = DurationEstimator.summarize(trial([sample(0), sample(2), sample(4, condition: .blank), sample(6), sample(18), sample(20)]))
        XCTAssertEqual(result.estimatedSlackSeconds, 4)
        XCTAssertEqual(result.unclassifiedSeconds, 16)
    }
    func testTransitionsAndIdleFramesAreConservative() {
        let result = DurationEstimator.summarize(trial([sample(0), sample(2, .workMail), sample(4, .workMail),
                                                      sample(6, .workMail, condition: .idle), sample(8, .workMail)], end: 8))
        XCTAssertEqual(result.estimatedMailSeconds, 2)
        XCTAssertEqual(result.unclassifiedSeconds, 6)
    }
    func testNoDataIsUnknownNotNonWork() {
        let result = DurationEstimator.summarize(trial([]))
        XCTAssertEqual(result.unclassifiedSeconds, 20)
        XCTAssertEqual(result.estimatedNonWorkSeconds, 0)
        XCTAssertEqual(result.estimatedCoverageFraction, 0)
    }
    func testUnsortedDuplicatesAndOutOfRangeSamplesDoNotDoubleCount() {
        let result = DurationEstimator.summarize(trial([sample(4), sample(2), sample(2), sample(-1), sample(22)], end: 4))
        XCTAssertEqual(result.estimatedSlackSeconds, 2)
        XCTAssertEqual(result.unclassifiedSeconds, 2)
    }
    func testWallClockChangesDoNotAlterDuration() {
        var a = sample(0); a.at = Date(timeIntervalSince1970: 90000)
        var b = sample(2); b.at = Date(timeIntervalSince1970: 10000)
        XCTAssertEqual(DurationEstimator.summarize(trial([a,b], end: 2)).estimatedSlackSeconds, 2)
    }
    func testServiceEventsNeverInventTimeOrDeviceAndDeduplicateBySource() {
        let event = ServiceEvent(id: "123", source: "slack:T:C", timestamp: Date(), description: "Reply", userAuthored: true)
        XCTAssertNil(event.durationSeconds)
        XCTAssertEqual(event.device, "unknown")
        XCTAssertEqual(EventMerge.merge([event, event], [event]).count, 1)
        let mail = ServiceEvent(id: "123", source: "gmail:work", timestamp: Date(), description: "Sent", userAuthored: true)
        XCTAssertEqual(EventMerge.merge([event], [mail]).count, 2)
    }
    func testUnknownDurationSurvivesEnvelopeRoundTrip() throws {
        let event = ServiceEvent(id: "m", source: "icloud:work", timestamp: Date(), description: "Sent", userAuthored: true)
        let result = try JSONDecoder().decode(ServiceEnvelope.self, from: JSONEncoder().encode(ServiceEnvelope(provider: "icloud", collectedAt: Date(), events: [event], limitations: [])))
        XCTAssertNil(result.events[0].durationSeconds)
    }
    func testReferenceComparisonShowsUnderestimateWithoutClaimingIntervalAccuracy() {
        var run = trial([sample(0), sample(2), sample(4)], end: 10)
        run.referenceSeconds = 8; run.referenceClass = .slack
        let result = ReferenceComparison.compare(run)
        XCTAssertEqual(result?.signedErrorSeconds, -4)
        XCTAssertEqual(result?.absoluteErrorFraction, 0.5)
        run.referenceSeconds = 0
        XCTAssertNil(ReferenceComparison.compare(run))
        run.referenceSeconds = 8; run.endedUptime = nil
        XCTAssertNil(ReferenceComparison.compare(run))
    }
}
