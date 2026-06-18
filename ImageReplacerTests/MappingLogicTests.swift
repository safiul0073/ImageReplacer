import XCTest
@testable import ImageReplacer

@MainActor
final class MappingLogicTests: XCTestCase {
    private let destinationFolder = URL(fileURLWithPath: "/tmp/destination", isDirectory: true)

    func testArbitraryFilenameMapping() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["new1.jpg", "new2.jpg", "new3.jpg"])
        viewModel.settings.sourceSortMode = .alphabeticalAscending
        viewModel.settings.destinationSortMode = .alphabeticalAscending
        viewModel.applyScannedDestinationImages(makeFiles(["account.jpg", "best.jpg", "last.jpg"]), in: destinationFolder)

        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.map(\.source.filename), ["new1.jpg", "new2.jpg", "new3.jpg"])
        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["account.jpg", "best.jpg", "last.jpg"])
    }

    func testStartingPositionUsesListPosition() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["source.jpg"])
        viewModel.settings.destinationSortMode = .natural
        viewModel.settings.startingPosition = 3
        viewModel.applyScannedDestinationImages(makeFiles(["account.jpg", "best.jpg", "image2.jpg", "image10.jpg", "last.jpg"]), in: destinationFolder)

        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.first?.destination.filename, "image2.jpg")
    }

    func testReplacementCountUsesMinimum() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles((1...12).map { "source\($0).jpg" })
        viewModel.applyScannedDestinationImages(makeFiles((1...50).map { "destination\($0).jpg" }), in: destinationFolder)
        viewModel.previewMapping()
        XCTAssertEqual(viewModel.mappings.count, 12)

        viewModel.sourceImages = makeFiles((1...50).map { "source\($0).jpg" })
        viewModel.applyScannedDestinationImages(makeFiles((1...12).map { "destination\($0).jpg" }), in: destinationFolder)
        viewModel.previewMapping()
        XCTAssertEqual(viewModel.mappings.count, 12)
    }

    func testOnlySpecificDestinationsAreMapped() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles((1...12).map { "source\($0).jpg" })
        let destinations = makeFiles((1...30).map { "destination\($0).jpg" })
        viewModel.applyScannedDestinationImages(destinations, in: destinationFolder)
        viewModel.clearDestinationSelection()

        let selectedNames = [
            "destination2.jpg", "destination3.jpg", "destination7.jpg", "destination9.jpg",
            "destination12.jpg", "destination14.jpg", "destination18.jpg", "destination20.jpg",
            "destination22.jpg", "destination25.jpg", "destination28.jpg", "destination30.jpg"
        ]
        for image in destinations where selectedNames.contains(image.filename) {
            viewModel.setDestinationSelected(true, for: image)
        }

        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), selectedNames)
        XCTAssertEqual(viewModel.mappings.count, 12)
    }

    func testSelectedDestinationsUseSortedOrderNotClickOrder() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["source1.jpg", "source2.jpg"])
        let destinations = makeFiles(["image10.jpg", "image2.jpg", "image1.jpg"])
        viewModel.settings.destinationSortMode = .natural
        viewModel.applyScannedDestinationImages(destinations, in: destinationFolder)
        viewModel.clearDestinationSelection()

        viewModel.setDestinationSelected(true, for: destinations.first { $0.filename == "image10.jpg" }!)
        viewModel.setDestinationSelected(true, for: destinations.first { $0.filename == "image1.jpg" }!)

        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["image1.jpg", "image10.jpg"])
    }

    func testSelectionRescanPreservesKnownFilesAndLeavesNewFilesUnchecked() {
        let viewModel = ImageReplacementViewModel()
        let initial = makeFiles(["account.jpg", "best.jpg"])
        viewModel.applyScannedDestinationImages(initial, in: destinationFolder)
        viewModel.setDestinationSelected(false, for: initial[1])

        let rescanned = makeFiles(["account.jpg", "best.jpg", "new.jpg"])
        viewModel.applyScannedDestinationImages(rescanned, in: destinationFolder)

        XCTAssertTrue(viewModel.isDestinationSelected(rescanned[0]))
        XCTAssertFalse(viewModel.isDestinationSelected(rescanned[1]))
        XCTAssertFalse(viewModel.isDestinationSelected(rescanned[2]))
    }

    func testStartingPositionExcludesEarlierCheckedDestinations() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["source1.jpg", "source2.jpg"])
        viewModel.settings.startingPosition = 3
        viewModel.applyScannedDestinationImages(makeFiles(["a.jpg", "b.jpg", "c.jpg", "d.jpg"]), in: destinationFolder)
        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["c.jpg", "d.jpg"])
        XCTAssertEqual(viewModel.destinationSelectionStatus(for: viewModel.orderedDestinationImages[0]), "Before start")
    }

    func testSelectionControlsAndZeroSelectionDisableReplacement() {
        let viewModel = ImageReplacementViewModel()
        viewModel.sourceImages = makeFiles(["source1.jpg", "source2.jpg"])
        viewModel.applyScannedDestinationImages(makeFiles(["a.jpg", "b.jpg", "c.jpg"]), in: destinationFolder)

        viewModel.clearDestinationSelection()
        XCTAssertEqual(viewModel.availableSelectedDestinationCount, 0)
        XCTAssertFalse(viewModel.canReplace)

        viewModel.selectFirstDestinationsMatchingSourceCount()
        XCTAssertEqual(viewModel.availableSelectedDestinationCount, 2)
        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["a.jpg", "b.jpg"])

        viewModel.invertDestinationSelection()
        XCTAssertEqual(viewModel.availableSelectedDestinationCount, 1)
        XCTAssertEqual(viewModel.mappings.first?.destination.filename, "c.jpg")

        viewModel.selectAllDestinations()
        XCTAssertEqual(viewModel.availableSelectedDestinationCount, 3)
        XCTAssertEqual(viewModel.unusedSelectedDestinationCount, 1)
    }

    func testChangingDestinationFolderResetsAndSelectsNewFolderFiles() {
        let viewModel = ImageReplacementViewModel()
        let firstFolder = URL(fileURLWithPath: "/tmp/first", isDirectory: true)
        let secondFolder = URL(fileURLWithPath: "/tmp/second", isDirectory: true)
        let firstImages = [ImageFile(url: firstFolder.appendingPathComponent("a.jpg"))]
        let secondImages = [ImageFile(url: secondFolder.appendingPathComponent("b.jpg"))]

        viewModel.applyScannedDestinationImages(firstImages, in: firstFolder)
        viewModel.clearDestinationSelection()
        viewModel.applyScannedDestinationImages(secondImages, in: secondFolder)

        XCTAssertEqual(viewModel.selectedDestinationCount, 1)
        XCTAssertTrue(viewModel.isDestinationSelected(secondImages[0]))
    }

    private func makeFiles(_ names: [String]) -> [ImageFile] {
        names.map { ImageFile(url: URL(fileURLWithPath: "/tmp/\($0)")) }
    }
}
