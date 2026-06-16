import Foundation

struct BackupService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func createBackup(for mappings: [ReplacementMapping], destinationFolder: URL, settings: AppSettings) throws -> URL {
        let backupRoot = destinationFolder.appendingPathComponent(Constants.backupRootName, isDirectory: true)
        try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let backupFolder = backupRoot.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: false)

        var entries: [BackupManifest.Entry] = []
        for mapping in mappings where mapping.include {
            guard mapping.destination.url.isInsideDirectory(destinationFolder) else {
                throw AppError.permissionDenied(mapping.destination.url.path)
            }
            let backupURL = backupFolder.appendingPathComponent(mapping.destination.filename)
            guard backupURL.isInsideDirectory(backupFolder) else {
                throw AppError.permissionDenied(backupURL.path)
            }
            do {
                try fileManager.copyItem(at: mapping.destination.url, to: backupURL)
            } catch {
                throw AppError.cannotCreateBackup(mapping.destination.filename)
            }
            entries.append(BackupManifest.Entry(
                originalDestinationPath: mapping.destination.url.path,
                backupPath: backupURL.path,
                sourcePath: mapping.source.url.path
            ))
        }

        let manifest = BackupManifest(
            creationDate: Date(),
            destinationFolder: destinationFolder.path,
            applicationVersion: Constants.appVersion,
            entries: entries,
            outputWidth: settings.width,
            outputHeight: settings.height,
            resizeMode: settings.resizeMode,
            jpegQuality: settings.jpegQuality
        )
        let data = try JSONEncoder.prettyDateEncoded.encode(manifest)
        try data.write(to: backupFolder.appendingPathComponent("manifest.json"), options: .atomic)
        return backupFolder
    }

    func latestBackup(in destinationFolder: URL) -> URL? {
        let backupRoot = destinationFolder.appendingPathComponent(Constants.backupRootName, isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        return urls
            .filter { $0.hasDirectoryPath && fileManager.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }

    func listBackups(in destinationFolder: URL) -> [URL] {
        let backupRoot = destinationFolder.appendingPathComponent(Constants.backupRootName, isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        return urls
            .filter { $0.hasDirectoryPath && fileManager.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func restoreBackup(at backupFolder: URL) throws -> ReplacementResult {
        let manifestURL = backupFolder.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder.prettyDateDecoded.decode(BackupManifest.self, from: data) else {
            throw AppError.invalidBackupManifest
        }

        var result = ReplacementResult()
        for entry in manifest.entries {
            let backupURL = URL(fileURLWithPath: entry.backupPath)
            let destinationURL = URL(fileURLWithPath: entry.originalDestinationPath)
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    _ = try fileManager.replaceItemAt(destinationURL, withItemAt: backupURL, backupItemName: nil, options: [.usingNewMetadataOnly])
                } else {
                    try fileManager.copyItem(at: backupURL, to: destinationURL)
                }
                result.restored += 1
            } catch {
                result.failed += 1
                result.failures.append(destinationURL.lastPathComponent)
            }
        }
        result.backupFolder = backupFolder
        return result
    }
}

private extension JSONEncoder {
    static var prettyDateEncoded: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var prettyDateDecoded: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

