import XCTest
@testable import ImageReplacer

final class FolderScannerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testPrefixFiltering() throws {
        try createFiles(["avatar-1.jpg", "avatar-john.png", "account.jpg", "profile.jpg"])
        var settings = AppSettings()
        settings.filenamePrefix = "avatar-"
        let result = try FolderScanner().scanDestinationImages(in: tempDirectory, settings: settings)
        XCTAssertEqual(result.images.map(\.filename).sorted(), ["avatar-1.jpg", "avatar-john.png"])
    }

    func testEmptyFiltersIncludeAllSupportedImages() throws {
        try createFiles(["account.jpg", "avatar.png", "profile.webp", "notes.txt", ".DS_Store"])
        let result = try FolderScanner().scanDestinationImages(in: tempDirectory, settings: AppSettings())
        XCTAssertEqual(result.images.map(\.filename).sorted(), ["account.jpg", "avatar.png", "profile.webp"])
    }

    private func createFiles(_ names: [String]) throws {
        for name in names {
            try Data([0x00]).write(to: tempDirectory.appendingPathComponent(name))
        }
    }
}

