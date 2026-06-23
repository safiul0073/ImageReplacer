import XCTest
@testable import ImageReplacer

@MainActor
final class MappingLogicTests: XCTestCase {
    private let sourceFolder = URL(fileURLWithPath: "/tmp/source", isDirectory: true)
    private let destinationFolder = URL(fileURLWithPath: "/tmp/destination", isDirectory: true)

    func testArbitraryFilenameMapping() {
        let viewModel = ImageReplacementViewModel()
        viewModel.applyScannedSourceImages(makeFiles(["new1.jpg", "new2.jpg", "new3.jpg"]), in: sourceFolder)
        viewModel.settings.sourceSortMode = .alphabeticalAscending
        viewModel.settings.destinationSortMode = .alphabeticalAscending
        viewModel.applyScannedDestinationImages(makeFiles(["account.jpg", "best.jpg", "last.jpg"]), in: destinationFolder)

        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.map(\.source.filename), ["new1.jpg", "new2.jpg", "new3.jpg"])
        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["account.jpg", "best.jpg", "last.jpg"])
    }

    func testStartingPositionUsesListPosition() {
        let viewModel = ImageReplacementViewModel()
        viewModel.applyScannedSourceImages(makeFiles(["source.jpg"]), in: sourceFolder)
        viewModel.settings.destinationSortMode = .natural
        viewModel.settings.startingPosition = 3
        viewModel.applyScannedDestinationImages(makeFiles(["account.jpg", "best.jpg", "image2.jpg", "image10.jpg", "last.jpg"]), in: destinationFolder)

        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.first?.destination.filename, "image2.jpg")
    }

    func testReplacementCountUsesMinimum() {
        let fewerSources = ImageReplacementViewModel()
        fewerSources.applyScannedSourceImages(makeFiles((1...12).map { "source\($0).jpg" }), in: sourceFolder)
        fewerSources.applyScannedDestinationImages(makeFiles((1...50).map { "destination\($0).jpg" }), in: destinationFolder)
        fewerSources.previewMapping()
        XCTAssertEqual(fewerSources.mappings.count, 12)

        let fewerDestinations = ImageReplacementViewModel()
        fewerDestinations.applyScannedSourceImages(makeFiles((1...50).map { "source\($0).jpg" }), in: sourceFolder)
        fewerDestinations.applyScannedDestinationImages(makeFiles((1...12).map { "destination\($0).jpg" }), in: destinationFolder)
        fewerDestinations.previewMapping()
        XCTAssertEqual(fewerDestinations.mappings.count, 12)
    }

    func testOnlySpecificDestinationsAreMapped() {
        let viewModel = ImageReplacementViewModel()
        viewModel.applyScannedSourceImages(makeFiles((1...12).map { "source\($0).jpg" }), in: sourceFolder)
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
        viewModel.applyScannedSourceImages(makeFiles(["source1.jpg", "source2.jpg"]), in: sourceFolder)
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
        viewModel.applyScannedSourceImages(makeFiles(["source1.jpg", "source2.jpg"]), in: sourceFolder)
        viewModel.settings.startingPosition = 3
        viewModel.applyScannedDestinationImages(makeFiles(["a.jpg", "b.jpg", "c.jpg", "d.jpg"]), in: destinationFolder)
        viewModel.previewMapping()

        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["c.jpg", "d.jpg"])
        XCTAssertEqual(viewModel.destinationSelectionStatus(for: viewModel.orderedDestinationImages[0]), "Before start")
    }

    func testSelectionControlsAndZeroSelectionDisableReplacement() {
        let viewModel = ImageReplacementViewModel()
        viewModel.applyScannedSourceImages(makeFiles(["source1.jpg", "source2.jpg"]), in: sourceFolder)
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

    func testBulkSelectionCanBeScopedToFilteredDestinations() {
        let viewModel = ImageReplacementViewModel()
        viewModel.applyScannedSourceImages(makeFiles(["source1.jpg", "source2.jpg"]), in: sourceFolder)
        let destinations = makeFiles(["avatar-1.jpg", "profile.jpg", "avatar-2.png", "account.jpg"])
        viewModel.applyScannedDestinationImages(destinations, in: destinationFolder)
        viewModel.clearDestinationSelection()

        let filtered = destinations.filter { $0.filename.localizedCaseInsensitiveContains("avatar") }
        viewModel.selectAllDestinations(in: filtered)

        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["avatar-1.jpg", "avatar-2.png"])
        XCTAssertFalse(viewModel.isDestinationSelected(destinations.first { $0.filename == "profile.jpg" }!))
        XCTAssertFalse(viewModel.isDestinationSelected(destinations.first { $0.filename == "account.jpg" }!))
    }

    func testBulkSelectionCanBeScopedToFilteredSources() {
        let viewModel = ImageReplacementViewModel()
        let sources = makeFiles(["avatar-1.jpg", "profile.jpg", "avatar-2.png", "account.jpg"])
        viewModel.applyScannedSourceImages(sources, in: sourceFolder)
        viewModel.applyScannedDestinationImages(makeFiles(["one.jpg", "two.jpg", "three.jpg"]), in: destinationFolder)
        viewModel.clearSourceSelection()

        let filtered = sources.filter { $0.filename.localizedCaseInsensitiveContains("avatar") }
        viewModel.selectAllSources(in: filtered)

        XCTAssertEqual(viewModel.mappings.map(\.source.filename), ["avatar-1.jpg", "avatar-2.png"])
        XCTAssertFalse(viewModel.isSourceSelected(sources.first { $0.filename == "profile.jpg" }!))
        XCTAssertFalse(viewModel.isSourceSelected(sources.first { $0.filename == "account.jpg" }!))
    }

    func testSourceSelectionRescanPreservesKnownFilesAndLeavesNewFilesUnchecked() {
        let viewModel = ImageReplacementViewModel()
        let initial = makeFiles(["first.jpg", "second.jpg"])
        viewModel.applyScannedSourceImages(initial, in: sourceFolder)
        viewModel.setSourceSelected(false, for: initial[1])

        let rescanned = makeFiles(["first.jpg", "second.jpg", "new.jpg"])
        viewModel.applyScannedSourceImages(rescanned, in: sourceFolder)

        XCTAssertTrue(viewModel.isSourceSelected(rescanned[0]))
        XCTAssertFalse(viewModel.isSourceSelected(rescanned[1]))
        XCTAssertFalse(viewModel.isSourceSelected(rescanned[2]))
    }

    func testNoSelectedSourcesProducesNoMappings() {
        let viewModel = ImageReplacementViewModel()
        viewModel.applyScannedSourceImages(makeFiles(["source.jpg"]), in: sourceFolder)
        viewModel.applyScannedDestinationImages(makeFiles(["destination.jpg"]), in: destinationFolder)

        viewModel.clearSourceSelection()

        XCTAssertEqual(viewModel.selectedSourceCount, 0)
        XCTAssertTrue(viewModel.mappings.isEmpty)
        XCTAssertFalse(viewModel.canReplace)
    }

    func testExplicitSourceDestinationPairsOverrideAutomaticOrder() {
        let viewModel = ImageReplacementViewModel()
        let sources = makeFiles(["new1.jpg", "new2.jpg", "new3.jpg"])
        let destinations = makeFiles(["account.jpg", "best.jpg", "last.jpg"])
        viewModel.applyScannedSourceImages(sources, in: sourceFolder)
        viewModel.applyScannedDestinationImages(destinations, in: destinationFolder)

        viewModel.setAssignedDestinationPath(path(for: destinations[2]), for: sources[0])
        viewModel.setAssignedDestinationPath(path(for: destinations[1]), for: sources[1])

        XCTAssertEqual(viewModel.mappings.map(\.source.filename), ["new1.jpg", "new2.jpg", "new3.jpg"])
        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["last.jpg", "best.jpg", "account.jpg"])
        XCTAssertEqual(viewModel.explicitPairCount, 2)
    }

    func testAssigningSameDestinationMovesPairToLatestSource() {
        let viewModel = ImageReplacementViewModel()
        let sources = makeFiles(["new1.jpg", "new2.jpg"])
        let destinations = makeFiles(["account.jpg", "best.jpg"])
        viewModel.applyScannedSourceImages(sources, in: sourceFolder)
        viewModel.applyScannedDestinationImages(destinations, in: destinationFolder)

        viewModel.setAssignedDestinationPath(path(for: destinations[1]), for: sources[0])
        viewModel.setAssignedDestinationPath(path(for: destinations[1]), for: sources[1])

        XCTAssertEqual(viewModel.assignedDestinationPath(for: sources[0]), "")
        XCTAssertEqual(viewModel.assignedDestinationPath(for: sources[1]), path(for: destinations[1]))
        XCTAssertEqual(viewModel.mappings.map(\.destination.filename), ["account.jpg", "best.jpg"])
    }

    func testExplicitPairSelectsSourceAndDestination() {
        let viewModel = ImageReplacementViewModel()
        let sources = makeFiles(["new1.jpg"])
        let destinations = makeFiles(["account.jpg"])
        viewModel.applyScannedSourceImages(sources, in: sourceFolder)
        viewModel.applyScannedDestinationImages(destinations, in: destinationFolder)
        viewModel.clearSourceSelection()
        viewModel.clearDestinationSelection()

        viewModel.setAssignedDestinationPath(path(for: destinations[0]), for: sources[0])

        XCTAssertTrue(viewModel.isSourceSelected(sources[0]))
        XCTAssertTrue(viewModel.isDestinationSelected(destinations[0]))
        XCTAssertEqual(viewModel.mappings.first?.source.filename, "new1.jpg")
        XCTAssertEqual(viewModel.mappings.first?.destination.filename, "account.jpg")
    }

    private func makeFiles(_ names: [String]) -> [ImageFile] {
        names.map { ImageFile(url: URL(fileURLWithPath: "/tmp/\($0)")) }
    }

    private func path(for file: ImageFile) -> String {
        file.url.standardizedFileURL.path
    }
}
