import Foundation
import ImageIO
import UniformTypeIdentifiers

extension URL {
    var normalizedExtension: String {
        pathExtension.lowercased()
    }

    var isHiddenOrTemporaryFile: Bool {
        let name = lastPathComponent
        return name.hasPrefix(".") || name.hasSuffix("~") || name.lowercased().hasSuffix(".tmp")
    }

    func isInsideDirectory(_ directory: URL) -> Bool {
        let filePath = standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        return filePath == directoryPath || filePath.hasPrefix(directoryPath + "/")
    }
}

extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension UTType {
    static func imageOutputType(forExtension ext: String) -> UTType? {
        switch ext.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "webp": return .webP
        case "heic": return .heic
        case "tiff", "tif": return .tiff
        case "bmp": return .bmp
        default: return nil
        }
    }
}

