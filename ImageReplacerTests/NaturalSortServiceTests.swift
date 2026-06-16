import XCTest
@testable import ImageReplacer

final class NaturalSortServiceTests: XCTestCase {
    func testNaturalSorting() {
        let files = makeFiles(["image10.jpg", "image2.jpg", "image1.jpg"])
        let sorted = NaturalSortService.sort(files, mode: ImageSortMode.natural).map(\.filename)
        XCTAssertEqual(sorted, ["image1.jpg", "image2.jpg", "image10.jpg"])
    }

    func testAlphabeticalSorting() {
        let files = makeFiles(["last.jpg", "account.jpg", "best.jpg"])
        let sorted = NaturalSortService.sort(files, mode: ImageSortMode.alphabeticalAscending).map(\.filename)
        XCTAssertEqual(sorted, ["account.jpg", "best.jpg", "last.jpg"])
    }

    func testNumberSorting() {
        let files = makeFiles(["1-450X450.jpg", "10-450X450.jpg", "2-450X450.jpg"])
        let sorted = NaturalSortService.sort(files, mode: DestinationSortMode.numberAscending).map(\.filename)
        XCTAssertEqual(sorted, ["1-450X450.jpg", "2-450X450.jpg", "10-450X450.jpg"])
    }

    private func makeFiles(_ names: [String]) -> [ImageFile] {
        names.map { ImageFile(url: URL(fileURLWithPath: "/tmp/\($0)")) }
    }
}

