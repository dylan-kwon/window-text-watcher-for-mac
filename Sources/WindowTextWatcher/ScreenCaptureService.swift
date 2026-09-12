import CoreImage
import CoreMedia
import ScreenCaptureKit

struct CaptureWindow: Identifiable {
    let id: CGWindowID
    let applicationName: String
    let title: String
    let source: SCWindow

    var displayName: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanTitle.isEmpty {
            return applicationName
        }

        return "\(applicationName) — \(cleanTitle)"
    }
}

@MainActor
final class ScreenCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: ((CGImage) -> Void)?
    var onHeartbeat: (() -> Void)?
    var onFailure: ((Error) -> Void)?

    private let sampleQueue = DispatchQueue(
        label: "WindowTextWatcher.ScreenCapture",
        qos: .userInteractive
    )
    nonisolated private let ciContext = CIContext(
        options: [CIContextOption.cacheIntermediates: false]
    )
    private var stream: SCStream?

    func loadWindows() async throws -> [CaptureWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        let ownBundleIdentifier = Bundle.main.bundleIdentifier

        return content.windows
            .filter { window in
                guard let application = window.owningApplication else {
                    return false
                }

                if application.bundleIdentifier == ownBundleIdentifier {
                    return false
                }

                return window.frame.width >= 80 && window.frame.height >= 80
            }
            .map { window in
                CaptureWindow(
                    id: window.windowID,
                    applicationName: window.owningApplication?.applicationName ?? "Unknown",
                    title: window.title ?? "",
                    source: window
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    func start(window: CaptureWindow) async throws {
        await stop()

        let filter = SCContentFilter(
            desktopIndependentWindow: window.source
        )
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.source.frame.width))
        configuration.height = max(1, Int(window.source.frame.height))
        configuration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: 12
        )
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: self
        )
        try stream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: sampleQueue
        )
        self.stream = stream
        do {
            try await stream.startCapture()
        } catch {
            self.stream = nil
            throw error
        }
    }

    func stop() async {
        guard let stream else {
            return
        }

        self.stream = nil
        try? await stream.stopCapture()
    }

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
              ) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else {
            return
        }

        let streamID = ObjectIdentifier(stream)
        if status == .idle {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.stream.map(ObjectIdentifier.init) == streamID else {
                    return
                }
                self.onHeartbeat?()
            }
            return
        }

        guard status == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let image = ciContext.createCGImage(
            ciImage,
            from: ciImage.extent
        ) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream.map(ObjectIdentifier.init) == streamID else {
                return
            }
            self.onFrame?(image)
        }
    }

    nonisolated func stream(
        _ stream: SCStream,
        didStopWithError error: Error
    ) {
        let streamID = ObjectIdentifier(stream)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream.map(ObjectIdentifier.init) == streamID else {
                return
            }
            self.stream = nil
            self.onFailure?(error)
        }
    }
}
