import Foundation
import SwiftUI

enum ResizeMode: String, CaseIterable, Identifiable, Codable {
    case centerCrop
    case aspectFit
    case stretch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .centerCrop: return "Center Crop"
        case .aspectFit: return "Fit Without Cropping"
        case .stretch: return "Stretch"
        }
    }
}

enum ImageSortMode: String, CaseIterable, Identifiable, Codable {
    case natural
    case alphabeticalAscending
    case alphabeticalDescending
    case createdOldest
    case createdNewest
    case modifiedOldest
    case modifiedNewest
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: return "Natural filename order"
        case .alphabeticalAscending: return "Alphabetical A-Z"
        case .alphabeticalDescending: return "Alphabetical Z-A"
        case .createdOldest: return "Date created: oldest first"
        case .createdNewest: return "Date created: newest first"
        case .modifiedOldest: return "Date modified: oldest first"
        case .modifiedNewest: return "Date modified: newest first"
        case .manual: return "Manual order"
        }
    }
}

enum DestinationSortMode: String, CaseIterable, Identifiable, Codable {
    case natural
    case alphabeticalAscending
    case alphabeticalDescending
    case numberAscending
    case numberDescending
    case createdOldest
    case createdNewest
    case modifiedOldest
    case modifiedNewest
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: return "Natural filename order"
        case .alphabeticalAscending: return "Alphabetical A-Z"
        case .alphabeticalDescending: return "Alphabetical Z-A"
        case .numberAscending: return "Number ascending"
        case .numberDescending: return "Number descending"
        case .createdOldest: return "Date created: oldest first"
        case .createdNewest: return "Date created: newest first"
        case .modifiedOldest: return "Date modified: oldest first"
        case .modifiedNewest: return "Date modified: newest first"
        case .manual: return "Manual order"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var filenamePrefix = ""
    var filenameSuffix = ""
    var filenameContains = ""
    var fileExtension = ""
    var startingPosition = 1
    var width = 450
    var height = 450
    var minimumWidth: Int?
    var minimumHeight: Int?
    var maximumWidth: Int?
    var maximumHeight: Int?
    var useDestinationDimensions = false
    var resizeMode: ResizeMode = .centerCrop
    var jpegQuality = 0.9
    var createBackup = true
    var overwriteExistingBackup = false
    var showConfirmation = true
    var moveUsedSourceImages = false
    var copyUsedSourceImages = false
    var preserveImageQuality = true
    var sourceSortMode: ImageSortMode = .natural
    var destinationSortMode: DestinationSortMode = .natural
    var jpegBackgroundHex = "#FFFFFF"

    var outputSize: CGSize {
        CGSize(width: width, height: height)
    }
}

