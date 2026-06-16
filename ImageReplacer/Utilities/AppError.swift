import Foundation

enum AppError: LocalizedError, Equatable {
    case sourceFolderNotSelected
    case destinationFolderNotSelected
    case sourceFolderUnavailable
    case destinationFolderUnavailable
    case noValidSourceImages
    case noDestinationImages
    case sameSourceAndDestination
    case invalidStartingPosition
    case invalidDimensions
    case cannotReadSourceImage(String)
    case cannotCreateBackup(String)
    case cannotWriteDestinationImage(String)
    case permissionDenied(String)
    case diskSpaceIssue
    case unsupportedImageFormat(String)
    case invalidBackupManifest
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .sourceFolderNotSelected:
            return "Choose a source images folder."
        case .destinationFolderNotSelected:
            return "Choose a placeholder destination folder."
        case .sourceFolderUnavailable:
            return "The source folder is unavailable. Select it again."
        case .destinationFolderUnavailable:
            return "The destination folder is unavailable. Select it again."
        case .noValidSourceImages:
            return "No supported source images were found."
        case .noDestinationImages:
            return "No supported destination images matched the current filters."
        case .sameSourceAndDestination:
            return "Source and destination folders must be different."
        case .invalidStartingPosition:
            return "Starting position must be within the destination image list."
        case .invalidDimensions:
            return "Width and height must be greater than zero."
        case .cannotReadSourceImage(let name):
            return "Could not read source image: \(name)."
        case .cannotCreateBackup(let name):
            return "Could not create backup for: \(name)."
        case .cannotWriteDestinationImage(let name):
            return "Could not write destination image: \(name)."
        case .permissionDenied(let path):
            return "Permission denied for: \(path)."
        case .diskSpaceIssue:
            return "There is not enough disk space to complete the replacement."
        case .unsupportedImageFormat(let ext):
            return "Unsupported image format: \(ext)."
        case .invalidBackupManifest:
            return "The backup manifest is missing or invalid."
        case .cancelled:
            return "Replacement was cancelled."
        case .unknown(let message):
            return message
        }
    }
}

