import Foundation

enum ReplacementStatus: String, Codable, Equatable {
    case ready = "Ready"
    case skipped = "Skipped"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

struct ReplacementMapping: Identifiable, Hashable, Codable {
    let id: UUID
    var order: Int
    var include: Bool
    let source: ImageFile
    let destination: ImageFile
    var status: ReplacementStatus
    var message: String?

    init(
        id: UUID = UUID(),
        order: Int,
        include: Bool = true,
        source: ImageFile,
        destination: ImageFile,
        status: ReplacementStatus = .ready,
        message: String? = nil
    ) {
        self.id = id
        self.order = order
        self.include = include
        self.source = source
        self.destination = destination
        self.status = status
        self.message = message
    }
}

