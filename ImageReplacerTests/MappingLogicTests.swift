import XCTest
@testable import ImageReplacer

@MainActor
final class MappingLogicTests: XCTestCase {
    func testArbitraryFilenameMapping() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["new1.jpg", "new2.jpg", "new3.jpg"])
        viewModel.destinationImages = makeFiles(["account.jpg", "best.jpg", "last.jpg"])
        viewModel.settings.sourceSortMode = .alphabeticalAscending
        viewModel.settings.destinationSortMode = .alphabeticalAscending

        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.map(\.source.filename), ["new1.jpg", "new2.jpg", "new3.jpg"])
        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["account.jpg", "best.jpg", "last.jpg"])
    }

    func testStartingPositionUsesListPosition() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["source.jpg"])
        viewModel.destinationImages = makeFiles(["account.jpg", "best.jpg", "image2.jpg", "image10.jpg", "last.jpg"])
        viewModel.settings.destinationSortMode = .natural
        viewModel.settings.startingPosition = 3

        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.first?.destination.filename, "image2.jpg")
    }

    func testReplacementCountUsesMinimum() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles((1...12).map { "source\($0).jpg" })
        viewModel.destinationImages = makeFiles((1...50).map { "destination\($0).jpg" })
        viewModel.previewMapping()
        XCTAssertEqual(viewModel.mappings.count, 12)

        viewModel.sourceImages = makeFiles((1...50).map { "source\($0).jpg" })
        viewModel.destinationImages = makeFiles((1...12).map { "destination\($0).jpg" })
        viewModel.previewMapping()
        XCTAssertEqual(viewModel.mappings.count, 12)
    }

    private func makeFiles(_ names: [String]) -> [ImageFile] {
        names.map { ImageFile(url: URL(fileURLWithPath: "/tmp/\($0)")) }
    }
}

