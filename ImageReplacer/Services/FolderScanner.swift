import Foundation
import ImageIO
import UniformTypeIdentifiers

struct DestinationScanSummary: Equatable {
    var total = 0
    var included = 0
    var excluded = 0
    var availableAfterStartingPosition = 0
}

struct FolderScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scanSourceImages(in folder: URL) throws -> [ImageFile] {
        try scanImages(in: folder, settings: nil).images
    }

    func scanDestinationImages(in folder: URL, settings: AppSettings) throws -> (images: [ImageFile], summary: DestinationScanSummary) {
        let result = try scanImages(in: folder, settings: settings)
        var summary = DestinationScanSummary()
        summary.total = result.total
        summary.included = result.images.count
        summary.excluded = max(0, result.total - result.images.count)
        summary.availableAfterStartingPosition = max(0, result.images.count - max(0, settings.startingPosition - 1))
        return (result.images, summary)
    }

    private func scanImages(in folder: URL, settings: AppSettings?) throws -> (images: [ImageFile], total: Int) {
        guard folder.hasDirectoryPath else { throw AppError.destinationFolderUnavailable }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isHiddenKey, .creationDateKey, .contentModificationDateKey]
        let urls = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        var images: [ImageFile] = []
        var totalSupportedImages = 0

        for url in urls {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isDirectory != true else { continue }
            guard !url.isHiddenOrTemporaryFile else { continue }
            guard !url.path.contains("/\(Constants.backupRootName)/") else { continue }
            guard Constants.supportedImageExtensions.contains(url.normalizedExtension) else { continue }
            totalSupportedImages += 1

            guard matches(url: url, settings: settings) else { continue }
            let size = imageSize(url: url)
            if let settings {
                guard matchesDimensions(width: size?.width, height: size?.height, settings: settings) else { continue }
            }

            images.append(ImageFile(
                url: url,
                createdAt: values.creationDate,
                modifiedAt: values.contentModificationDate,
                width: size?.width,
                height: size?.height
            ))
        }

        return (images, totalSupportedImages)
    }

    private func matches(url: URL, settings: AppSettings?) -> Bool {
        guard let settings else { return true }
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        if let prefix = settings.filenamePrefix.nilIfBlank, !nameWithoutExtension.hasPrefix(prefix) { return false }
        if let suffix = settings.filenameSuffix.nilIfBlank, !nameWithoutExtension.hasSuffix(suffix) { return false }
        if let contains = settings.filenameContains.nilIfBlank, nameWithoutExtension.range(of: contains, options: .caseInsensitive) == nil { return false }
        if let ext = settings.fileExtension.nilIfBlank, url.normalizedExtension != ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) { return false }
        return true
    }

    private func matchesDimensions(width: Int?, height: Int?, settings: AppSettings) -> Bool {
        guard let width, let height else {
            return settings.minimumWidth == nil && settings.minimumHeight == nil && settings.maximumWidth == nil && settings.maximumHeight == nil
        }
        if let minimumWidth = settings.minimumWidth, width < minimumWidth { return false }
        if let minimumHeight = settings.minimumHeight, height < minimumHeight { return false }
        if let maximumWidth = settings.maximumWidth, width > maximumWidth { return false }
        if let maximumHeight = settings.maximumHeight, height > maximumHeight { return false }
        return true
    }

    private func imageSize(url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (width, height)
    }
}

