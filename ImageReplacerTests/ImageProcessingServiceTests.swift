import XCTest
import UniformTypeIdentifiers
@testable import ImageReplacer

final class ImageProcessingServiceTests: XCTestCase {
    func testCenterCropCalculation() {
        let rect = ImageProcessingService.drawRect(
            sourceSize: CGSize(width: 100, height: 50),
            targetSize: CGSize(width: 50, height: 50),
            resizeMode: .centerCrop
        )
        XCTAssertEqual(rect.width, 100)
        XCTAssertEqual(rect.height, 50)
        XCTAssertEqual(rect.origin.x, -25)
    }

    func testAspectFitCalculation() {
        let rect = ImageProcessingService.drawRect(
            sourceSize: CGSize(width: 100, height: 50),
            targetSize: CGSize(width: 50, height: 50),
            resizeMode: .aspectFit
        )
        XCTAssertEqual(rect.width, 50)
        XCTAssertEqual(rect.height, 25)
        XCTAssertEqual(rect.origin.y, 12.5)
    }

    func testMixedExtensionOutputTypeSelection() {
        XCTAssertNotNil(UTType.imageOutputType(forExtension: "jpg"))
        XCTAssertNotNil(UTType.imageOutputType(forExtension: "png"))
        XCTAssertNotNil(UTType.imageOutputType(forExtension: "webp"))
    }
}
