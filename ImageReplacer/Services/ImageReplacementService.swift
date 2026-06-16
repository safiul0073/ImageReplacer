import AppKit
import Foundation
import os

struct ReplacementProgress: Equatable {
    var currentFile = ""
    var currentIndex = 0
    var total = 0
    var percent: Double {
        guard total > 0 else { return 0 }
        return Double(currentIndex) / Double(total)
    }
}

struct ImageReplacementService: @unchecked Sendable {
    private let fileManager: FileManager
    private let processor: ImageProcessingService
    private let backupService: BackupService
    private let logger = Logger(subsystem: "ImageReplacer", category: "Replacement")

    init(fileManager: FileManager = .default, processor: ImageProcessingService = ImageProcessingService(), backupService: BackupService = BackupService()) {
        self.fileManager = fileManager
        self.processor = processor
        self.backupService = backupService
    }

    func replace(
        mappings: [ReplacementMapping],
        destinationFolder: URL,
        settings: AppSettings,
        progress: @escaping @Sendable (ReplacementProgress) async -> Void
    ) async throws -> ReplacementResult {
        let selected = mappings.filter(\.include)
        var result = ReplacementResult()
        var backupFolder: URL?
        if settings.createBackup {
            backupFolder = try backupService.createBackup(for: selected, destinationFolder: destinationFolder, settings: settings)
            result.backupFolder = backupFolder
        }

        for (index, mapping) in selected.enumerated() {
            try Task.checkCancellation()
            await progress(ReplacementProgress(currentFile: mapping.destination.filename, currentIndex: index + 1, total: selected.count))
            guard mapping.destination.url.isInsideDirectory(destinationFolder) else {
                throw AppError.permissionDenied(mapping.destination.url.path)
            }

            do {
                let targetSize = try targetSize(for: mapping, settings: settings)
                let data = try processor.process(
                    sourceURL: mapping.source.url,
                    destinationURL: mapping.destination.url,
                    targetSize: targetSize,
                    resizeMode: settings.resizeMode,
                    jpegQuality: settings.jpegQuality
                )
                let tempURL = mapping.destination.url.deletingLastPathComponent().appendingPathComponent(".image-replacer-\(UUID().uuidString).tmp")
                try data.write(to: tempURL, options: .atomic)
                _ = try fileManager.replaceItemAt(mapping.destination.url, withItemAt: tempURL, backupItemName: nil, options: [.usingNewMetadataOnly])
                result.successful += 1
            } catch is CancellationError {
                throw AppError.cancelled
            } catch let appError as AppError {
                logger.error("Replacement failed: \(appError.localizedDescription, privacy: .public)")
                result.failed += 1
                result.failures.append(mapping.destination.filename)
                throw appError
            } catch {
                logger.error("Replacement failed: \(error.localizedDescription, privacy: .public)")
                result.failed += 1
                result.failures.append(mapping.destination.filename)
                throw AppError.cannotWriteDestinationImage(mapping.destination.filename)
            }
        }

        if settings.moveUsedSourceImages {
            result.movedSourceFiles = try moveUsedSources(selected.prefix(result.successful).map(\.source.url))
        } else if settings.copyUsedSourceImages {
            result.movedSourceFiles = try copyUsedSources(selected.prefix(result.successful).map(\.source.url))
        }

        result.skipped = mappings.filter { !$0.include }.count
        result.backupFolder = backupFolder
        return result
    }

    private func targetSize(for mapping: ReplacementMapping, settings: AppSettings) throws -> CGSize {
        if settings.useDestinationDimensions, let width = mapping.destination.width, let height = mapping.destination.height {
            return CGSize(width: width, height: height)
        }
        guard settings.width > 0, settings.height > 0 else { throw AppError.invalidDimensions }
        return CGSize(width: settings.width, height: settings.height)
    }

    private func moveUsedSources(_ urls: [URL]) throws -> Int {
        var count = 0
        for url in urls {
            let usedFolder = url.deletingLastPathComponent().appendingPathComponent(Constants.usedFolderName, isDirectory: true)
            try fileManager.createDirectory(at: usedFolder, withIntermediateDirectories: true)
            let destination = Self.uniqueURL(for: url.lastPathComponent, in: usedFolder, fileManager: fileManager)
            try fileManager.moveItem(at: url, to: destination)
            count += 1
        }
        return count
    }

    private func copyUsedSources(_ urls: [URL]) throws -> Int {
        var count = 0
        for url in urls {
            let usedFolder = url.deletingLastPathComponent().appendingPathComponent(Constants.usedFolderName, isDirectory: true)
            try fileManager.createDirectory(at: usedFolder, withIntermediateDirectories: true)
            let destination = Self.uniqueURL(for: url.lastPathComponent, in: usedFolder, fileManager: fileManager)
            try fileManager.copyItem(at: url, to: destination)
            count += 1
        }
        return count
    }

    static func uniqueURL(for filename: String, in folder: URL, fileManager: FileManager = .default) -> URL {
        let original = folder.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: original.path) else { return original }
        let base = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        var index = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
