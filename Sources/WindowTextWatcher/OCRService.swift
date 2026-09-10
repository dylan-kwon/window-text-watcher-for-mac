import CoreGraphics
import Vision

final class OCRService {
    enum OCRError: Error {
        case noResult
    }

    private let queue = DispatchQueue(
        label: "WindowTextWatcher.OCR",
        qos: .userInitiated
    )

    func recognize(
        image: CGImage,
        topLeftNormalizedRegion: CGRect,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let region = sanitizedRegion(topLeftNormalizedRegion)

        queue.async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = true
            request.regionOfInterest = RegionMapper.visionRegion(
                fromTopLeftNormalized: region
            )

            do {
                let handler = VNImageRequestHandler(
                    cgImage: image,
                    orientation: .up,
                    options: [:]
                )
                try handler.perform([request])

                let text = (request.results ?? [])
                    .compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    .joined(separator: "\n")

                DispatchQueue.main.async {
                    completion(.success(text))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func sanitizedRegion(_ region: CGRect) -> CGRect {
        let standardized = region.standardized
        let intersection = standardized.intersection(
            CGRect(x: 0, y: 0, width: 1, height: 1)
        )

        if intersection.isNull || intersection.width < 0.001 || intersection.height < 0.001 {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        return intersection
    }
}
