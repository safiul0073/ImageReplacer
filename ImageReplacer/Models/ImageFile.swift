import Foundation
import CoreGraphics

struct ImageFile: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    let filename: String
    let fileExtension: String
    let createdAt: Date?
    let modifiedAt: Date?
    let width: Int?
    let height: Int?

    init(
        id: UUID = UUID(),
        url: URL,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.filename = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.width = width
        self.height = height
    }

    var displaySize: String {
        guard let width, let height else { return "Unknown" }
        return "\(width)x\(height)"
    }
}

