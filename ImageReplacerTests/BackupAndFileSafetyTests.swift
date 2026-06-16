import XCTest
@testable import ImageReplacer

final class BackupAndFileSafetyTests: XCTestCase {
    func testBackupManifestEncodingAndDecoding() throws {
        let manifest = BackupManifest(
            creationDate: Date(timeIntervalSince1970: 1_800_000_000),
            destinationFolder: "/tmp/destination",
            applicationVersion: "1.0",
            entries: [
                .init(originalDestinationPath: "/tmp/destination/account.jpg", backupPath: "/tmp/backup/account.jpg", sourcePath: "/tmp/source/new.jpg")
            ],
            outputWidth: 450,
            outputHeight: 450,
            resizeMode: .centerCrop,
            jpegQuality: 0.9
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }

    func testDestinationPathValidation() {
        let root = URL(fileURLWithPath: "/tmp/destination")
        XCTAssertTrue(URL(fileURLWithPath: "/tmp/destination/account.jpg").isInsideDirectory(root))
        XCTAssertFalse(URL(fileURLWithPath: "/tmp/destination-other/account.jpg").isInsideDirectory(root))
    }

    func testUniqueFilenameGeneration() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data().write(to: folder.appendingPathComponent("photo.jpg"))
        let unique = ImageReplacementService.uniqueURL(for: "photo.jpg", in: folder)
        XCTAssertEqual(unique.lastPathComponent, "photo-2.jpg")
    }
}

