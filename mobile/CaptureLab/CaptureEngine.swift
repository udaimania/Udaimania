import Foundation
import Combine
import UIKit
import CoreMedia
import ImageIO
import CaptureCore
#if canImport(ScreenCaptureKit) && !targetEnvironment(simulator)
@preconcurrency import ScreenCaptureKit
@preconcurrency import Vision

/// The callback queue owns sample throttling. Images live only during OCR; no image/video writer exists.
final class FrameAnalyzer: NSObject, SCStreamOutput, @unchecked Sendable {
    private let rules: [MatchRule]
    private let retainExcerpts: Bool
    private let receive: @Sendable (CaptureSample) -> Void
    private var lastSampleUptime = -Double.infinity
    private let lock = NSLock()
    private var ownAppIsActive = true
    private var acceptsSamples = true
    init(rules: [MatchRule], retainExcerpts: Bool, receive: @escaping @Sendable (CaptureSample) -> Void) {
        self.rules = rules; self.retainExcerpts = retainExcerpts; self.receive = receive
    }
    func setOwnAppActive(_ value: Bool) { lock.lock(); ownAppIsActive = value; lock.unlock() }
    func invalidate() { lock.lock(); acceptsSamples = false; lock.unlock() }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastSampleUptime >= 2 else { return }
        lastSampleUptime = uptime
        lock.lock(); let active = ownAppIsActive; let accepts = acceptsSamples; lock.unlock()
        guard accepts else { return }
        let at = Date()
        var condition: FrameCondition = active ? .ownApp : .readable
        let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        if let raw = (attachments?.first?[.status] as? NSNumber)?.intValue, let status = SCFrameStatus(rawValue: raw) {
            switch status {
            case .blank: condition = .blank
            case .suspended: condition = .suspended
            case .idle: condition = .idle
            case .stopped: condition = .stopped
            case .complete, .started: break
            @unknown default: condition = .failed
            }
        }
        guard condition == .readable, let image = CMSampleBufferGetImageBuffer(buffer) else {
            receive(.init(at: at, uptime: uptime, condition: condition,
                          classification: .init(kind: .unknown, reason: condition.rawValue)))
            return
        }
        let started = ProcessInfo.processInfo.systemUptime
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            // ScreenCaptureKit supplies display-oriented buffers; orientation correctness is a hardware trial.
            try VNImageRequestHandler(cvPixelBuffer: image, orientation: .up).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            let result = Classifier.classify(text, rules: rules)
            let work = result.kind == .slack || result.kind == .workMail
            receive(.init(at: at, uptime: uptime, condition: .readable, classification: result,
                          recognizedCharacters: text.count,
                          processingMilliseconds: (ProcessInfo.processInfo.systemUptime - started) * 1000,
                          excerpt: retainExcerpts && work ? String(text.prefix(1200)) : nil))
        } catch {
            receive(.init(at: at, uptime: uptime, condition: .failed,
                          classification: .init(kind: .unknown, reason: "OCR failed")))
        }
    }
}

@MainActor
final class CaptureEngine: NSObject, ObservableObject, SCContentSharingPickerObserver, SCStreamDelegate {
    @Published var status = "Ready for a device trial"
    @Published var activeTrialID: UUID?
    @Published var isStarting = false
    private weak var store: LabStore?
    private var capture: SCStream?
    private var analyzer: FrameAnalyzer?
    private var requestedName = ""
    private var timeout: Task<Void, Never>?
    private let queue = DispatchQueue(label: "com.udaimania.capturelab.ocr", qos: .utility)
    private var appActive = true
    private var generation = UUID()

    var isRecording: Bool { activeTrialID != nil }
    var simulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    func start(name: String, store: LabStore) {
        guard !isRecording, !isStarting else { return }
        guard !simulator else { status = "Cross-app screen capture must be tested on the physical iPhone."; return }
        self.store = store; requestedName = name
        let picker = SCContentSharingPicker.shared
        guard picker.isAvailable else { status = "The system reports screen capture is unavailable on this device."; return }
        isStarting = true; status = "Choose full-display capture in the system picker"
        var configuration = SCContentSharingPickerConfiguration()
        configuration.showsMicrophoneControl = false
        configuration.showsCameraControl = false
        picker.defaultConfiguration = configuration
        picker.add(self); picker.isActive = true; picker.present()
    }

    func setAppActive(_ active: Bool) {
        appActive = active; analyzer?.setOwnAppActive(active)
        store?.lifecycle(active ? "app-active" : "app-not-active", trial: activeTrialID)
    }

    func stop(reason: String = "Stopped by user") async {
        generation = UUID()
        timeout?.cancel(); timeout = nil
        analyzer?.invalidate()
        let old = capture
        capture = nil
        if let id = activeTrialID { store?.finish(id, reason: reason) }
        activeTrialID = nil; isStarting = false
        var finalStatus = reason
        if let old {
            do { try await old.stopCapture() }
            catch { finalStatus = "\(reason); system stop returned \(error.localizedDescription)" }
        }
        analyzer = nil
        SCContentSharingPicker.shared.remove(self)
        SCContentSharingPicker.shared.isActive = false
        status = finalStatus
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in await self.stop(reason: "Capture selection cancelled") }
    }
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor in await self.stop(reason: "Picker failed: \(message)") }
    }
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in await self.beginCapture(filter: filter) }
    }
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            guard self.capture === stream else { return }
            await self.stop(reason: "System interruption: \(message)")
        }
    }
    private func beginCapture(filter: SCContentFilter) async {
        guard capture == nil, let store, isStarting else { return }
        let token = UUID(); generation = token
        let id = store.begin(name: requestedName)
        activeTrialID = id
        let analysis = FrameAnalyzer(rules: store.rules, retainExcerpts: store.retainWorkExcerpts) { [weak store] sample in
            Task { @MainActor in store?.append(sample, to: id) }
        }
        analysis.setOwnAppActive(appActive)
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = false
        // iOS does not expose minimumFrameInterval or excludedBundleIDs. We throttle
        // OCR ourselves; the capture stream's own frame rate and energy cost are not reduced.
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(analysis, type: .screen, sampleHandlerQueue: queue)
            capture = stream; analyzer = analysis
            try await stream.startCapture()
            guard generation == token else { try? await stream.stopCapture(); return }
            isStarting = false; status = "Capturing • OCR every 2 seconds • local only"
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                await self?.stop(reason: "Five-minute trial limit reached")
            }
        } catch {
            await stop(reason: "Capture failed: \(error.localizedDescription)")
        }
    }
}
#else
@MainActor
final class CaptureEngine: ObservableObject {
    @Published var status = "Simulator • screen capture requires a physical iPhone"
    @Published var activeTrialID: UUID?
    @Published var isStarting = false
    var simulator: Bool { true }
    var isRecording: Bool { false }
    func start(name: String, store: LabStore) { status = "Physical iPhone required; no simulated capture results are generated." }
    func setAppActive(_ active: Bool) {}
    func stop(reason: String = "Stopped") async {}
}
#endif
