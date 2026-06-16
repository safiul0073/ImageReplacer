import Foundation

struct ReplacementResult: Codable, Equatable {
    var successful = 0
    var failed = 0
    var skipped = 0
    var movedSourceFiles = 0
    var backupFolder: URL?
    var failures: [String] = []
    var restored = 0
}

struct BackupManifest: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let originalDestinationPath: String
        let backupPath: String
        let sourcePath: String
    }

    let creationDate: Date
    let destinationFolder: String
    let applicationVersion: String
    let entries: [Entry]
    let outputWidth: Int
    let outputHeight: Int
    let resizeMode: ResizeMode
    let jpegQuality: Double
}

