import Foundation

enum NaturalSortService {
    static func sort(_ files: [ImageFile], mode: ImageSortMode) -> [ImageFile] {
        switch mode {
        case .natural:
            return files.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .alphabeticalAscending:
            return files.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
        case .alphabeticalDescending:
            return files.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedDescending }
        case .createdOldest:
            return files.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .createdNewest:
            return files.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .modifiedOldest:
            return files.sorted { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }
        case .modifiedNewest:
            return files.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        case .manual:
            return files
        }
    }

    static func sort(_ files: [ImageFile], mode: DestinationSortMode) -> [ImageFile] {
        switch mode {
        case .natural:
            return files.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .alphabeticalAscending:
            return files.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
        case .alphabeticalDescending:
            return files.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedDescending }
        case .numberAscending:
            return files.sorted { numericKey($0.filename) < numericKey($1.filename) }
        case .numberDescending:
            return files.sorted { numericKey($0.filename) > numericKey($1.filename) }
        case .createdOldest:
            return files.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .createdNewest:
            return files.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .modifiedOldest:
            return files.sorted { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }
        case .modifiedNewest:
            return files.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        case .manual:
            return files
        }
    }

    static func firstNumber(in filename: String) -> Int? {
        let pattern = #"\d+"#
        guard let range = filename.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(filename[range])
    }

    private static func numericKey(_ filename: String) -> (Int, String) {
        (firstNumber(in: filename) ?? Int.max, filename)
    }
}

