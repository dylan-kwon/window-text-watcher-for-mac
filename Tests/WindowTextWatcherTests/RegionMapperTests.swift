import CoreGraphics
import XCTest
@testable import WindowTextWatcher

final class RegionMapperTests: XCTestCase {
    func testMapsDragInsideAspectFitImageToNormalizedTopLeftCoordinates() {
        let mapper = RegionMapper(
            viewSize: CGSize(width: 1000, height: 800),
            imageSize: CGSize(width: 1600, height: 900)
        )

        let rect = mapper.normalizedRect(
            from: CGPoint(x: 100, y: 175),
            to: CGPoint(x: 500, y: 400)
        )

        XCTAssertEqual(rect.origin.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.y, 0.1, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 0.4, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 0.4, accuracy: 0.0001)
    }

    func testMapsNormalizedRegionBackToPreviewCoordinates() {
        let mapper = RegionMapper(
            viewSize: CGSize(width: 1000, height: 800),
            imageSize: CGSize(width: 1600, height: 900)
        )

        let rect = mapper.viewRect(
            fromTopLeftNormalized: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4)
        )

        XCTAssertEqual(rect.origin.x, 100, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.y, 175, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 400, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 225, accuracy: 0.0001)
    }

    func testClampsSelectionToVisibleImageBounds() {
        let mapper = RegionMapper(
            viewSize: CGSize(width: 1000, height: 800),
            imageSize: CGSize(width: 1600, height: 900)
        )

        let rect = mapper.normalizedRect(
            from: CGPoint(x: -100, y: 0),
            to: CGPoint(x: 1200, y: 1000)
        )

        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 1, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 1, accuracy: 0.0001)
    }

    func testConvertsTopLeftRegionToVisionBottomLeftRegion() {
        let rect = CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.25)

        let visionRect = RegionMapper.visionRegion(fromTopLeftNormalized: rect)

        XCTAssertEqual(visionRect.origin.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(visionRect.origin.y, 0.65, accuracy: 0.0001)
        XCTAssertEqual(visionRect.width, 0.5, accuracy: 0.0001)
        XCTAssertEqual(visionRect.height, 0.25, accuracy: 0.0001)
    }
}
