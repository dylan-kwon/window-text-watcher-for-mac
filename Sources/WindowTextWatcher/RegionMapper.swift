import CoreGraphics

struct RegionMapper {
    let viewSize: CGSize
    let imageSize: CGSize

    func normalizedRect(
        from start: CGPoint,
        to end: CGPoint
    ) -> CGRect {
        guard let imageFrame else {
            return .zero
        }

        let clampedStart = clamp(start, to: imageFrame)
        let clampedEnd = clamp(end, to: imageFrame)
        let minX = min(clampedStart.x, clampedEnd.x)
        let maxX = max(clampedStart.x, clampedEnd.x)
        let minY = min(clampedStart.y, clampedEnd.y)
        let maxY = max(clampedStart.y, clampedEnd.y)

        return CGRect(
            x: (minX - imageFrame.minX) / imageFrame.width,
            y: (minY - imageFrame.minY) / imageFrame.height,
            width: (maxX - minX) / imageFrame.width,
            height: (maxY - minY) / imageFrame.height
        )
    }

    func viewRect(fromTopLeftNormalized normalizedRect: CGRect) -> CGRect {
        guard let imageFrame else {
            return .zero
        }

        let rect = normalizedRect.standardized
        return CGRect(
            x: imageFrame.minX + (rect.minX * imageFrame.width),
            y: imageFrame.minY + (rect.minY * imageFrame.height),
            width: rect.width * imageFrame.width,
            height: rect.height * imageFrame.height
        )
    }

    static func visionRegion(fromTopLeftNormalized rect: CGRect) -> CGRect {
        let standardized = rect.standardized
        return CGRect(
            x: standardized.minX,
            y: 1 - standardized.maxY,
            width: standardized.width,
            height: standardized.height
        )
    }

    private var imageFrame: CGRect? {
        guard viewSize.width > 0,
              viewSize.height > 0,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return nil
        }

        let scale = min(
            viewSize.width / imageSize.width,
            viewSize.height / imageSize.height
        )
        let displayedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (viewSize.width - displayedSize.width) / 2,
            y: (viewSize.height - displayedSize.height) / 2,
            width: displayedSize.width,
            height: displayedSize.height
        )
    }

    private func clamp(
        _ point: CGPoint,
        to rect: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }
}
