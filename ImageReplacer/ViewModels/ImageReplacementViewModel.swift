import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ImageReplacementViewModel: ObservableObject {
    @Published var sourceFolder: URL?
    @Published var destinationFolder: URL?
    @Published var sourceImages: [ImageFile] = []
    @Published var destinationImages: [ImageFile] = []
    @Published var mappings: [ReplacementMapping] = []
    @Published var settings = AppSettings() {
        didSet { saveSettings() }
    }
    @Published var destinationSummary = DestinationScanSummary()
    @Published var progress = ReplacementProgress()
    @Published var result: ReplacementResult?
    @Published var errorMessage: String?
    @Published var isScanning = false
    @Published var isReplacing = false
    @Published var showingConfirmation = false
    @Published var availableBackups: [URL] = []

    private let scanner = FolderScanner()
    private let replacementService = ImageReplacementService()
    private let backupService = BackupService()
    private let bookmarkService = SecurityScopedBookmarkService()
    private var replacementTask: Task<Void, Never>?
    private let settingsKey = "appSettings"
    private let sourceBookmarkKey = "sourceFolderBookmark"
    private let destinationBookmarkKey = "destinationFolderBookmark"

    init() {
        loadPersistedState()
    }

    var canPreview: Bool {
        sourceFolder != nil && destinationFolder != nil && !sourceImages.isEmpty && !destinationImages.isEmpty
    }

    var canReplace: Bool {
        !isReplacing && mappings.contains { $0.include }
    }

    var selectedMappingsCount: Int {
        mappings.filter(\.include).count
    }

    func selectSourceFolder() {
        chooseFolder { [weak self] url in
            self?.sourceFolder = url
            self?.saveBookmark(url, key: self?.sourceBookmarkKey ?? "sourceFolderBookmark")
        }
    }

    func selectDestinationFolder() {
        chooseFolder { [weak self] url in
            self?.destinationFolder = url
            self?.saveBookmark(url, key: self?.destinationBookmarkKey ?? "destinationFolderBookmark")
            self?.refreshBackups()
        }
    }

    func acceptDroppedFolder(_ providers: [NSItemProvider], destination: FolderDropTarget) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.folder.identifier) || $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            errorMessage = "Drop a folder, not an individual file."
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.hasDirectoryPath else {
                Task { @MainActor in self?.errorMessage = "Drop a folder, not an individual file." }
                return
            }
            Task { @MainActor in
                switch destination {
                case .source:
                    self?.sourceFolder = url
                    self?.saveBookmark(url, key: self?.sourceBookmarkKey ?? "sourceFolderBookmark")
                case .destination:
                    self?.destinationFolder = url
                    self?.saveBookmark(url, key: self?.destinationBookmarkKey ?? "destinationFolderBookmark")
                    self?.refreshBackups()
                }
            }
        }
        return true
    }

    func scanFolders() {
        errorMessage = nil
        guard let sourceFolder else {
            errorMessage = AppError.sourceFolderNotSelected.localizedDescription
            return
        }
        guard let destinationFolder else {
            errorMessage = AppError.destinationFolderNotSelected.localizedDescription
            return
        }
        guard sourceFolder.standardizedFileURL != destinationFolder.standardizedFileURL else {
            errorMessage = AppError.sameSourceAndDestination.localizedDescription
            return
        }
        guard settings.width > 0, settings.height > 0 else {
            errorMessage = AppError.invalidDimensions.localizedDescription
            return
        }

        isScanning = true
        Task {
            do {
                let sourceAccess = bookmarkService.startAccessing(sourceFolder)
                let destinationAccess = bookmarkService.startAccessing(destinationFolder)
                defer {
                    if sourceAccess { bookmarkService.stopAccessing(sourceFolder) }
                    if destinationAccess { bookmarkService.stopAccessing(destinationFolder) }
                }
                let source = try scanner.scanSourceImages(in: sourceFolder)
                let destination = try scanner.scanDestinationImages(in: destinationFolder, settings: settings)
                await MainActor.run {
                    self.sourceImages = NaturalSortService.sort(source, mode: self.settings.sourceSortMode)
                    self.destinationImages = NaturalSortService.sort(destination.images, mode: self.settings.destinationSortMode)
                    self.destinationSummary = destination.summary
                    self.isScanning = false
                    self.previewMapping()
                    self.refreshBackups()
                    if self.sourceImages.isEmpty { self.errorMessage = AppError.noValidSourceImages.localizedDescription }
                    if self.destinationImages.isEmpty { self.errorMessage = AppError.noDestinationImages.localizedDescription }
                }
            } catch {
                await MainActor.run {
                    self.isScanning = false
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    func previewMapping() {
        errorMessage = nil
        guard settings.startingPosition >= 1 else {
            errorMessage = AppError.invalidStartingPosition.localizedDescription
            return
        }
        let sortedSources = NaturalSortService.sort(sourceImages, mode: settings.sourceSortMode)
        let sortedDestinations = NaturalSortService.sort(destinationImages, mode: settings.destinationSortMode)
        guard settings.startingPosition <= max(1, sortedDestinations.count) else {
            errorMessage = AppError.invalidStartingPosition.localizedDescription
            mappings = []
            return
        }
        let startIndex = settings.startingPosition - 1
        let available = Array(sortedDestinations.dropFirst(startIndex))
        let count = min(sortedSources.count, available.count)
        mappings = (0..<count).map {
            ReplacementMapping(order: $0 + 1, source: sortedSources[$0], destination: available[$0])
        }
        destinationSummary.availableAfterStartingPosition = available.count
    }

    func replaceImages() {
        guard canReplace, let destinationFolder else { return }
        if settings.showConfirmation {
            showingConfirmation = true
            return
        }
        startReplacement(destinationFolder: destinationFolder)
    }

    func confirmReplacement() {
        showingConfirmation = false
        guard let destinationFolder else { return }
        startReplacement(destinationFolder: destinationFolder)
    }

    func cancelReplacement() {
        replacementTask?.cancel()
    }

    func restoreLastBackup() {
        guard let destinationFolder, let latest = backupService.latestBackup(in: destinationFolder) else {
            errorMessage = "No valid backup was found."
            return
        }
        restoreBackup(at: latest)
    }

    func restoreBackup(at url: URL) {
        do {
            result = try backupService.restoreBackup(at: url)
            refreshBackups()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshBackups() {
        guard let destinationFolder else {
            availableBackups = []
            return
        }
        availableBackups = backupService.listBackups(in: destinationFolder)
    }

    func clear() {
        sourceFolder = nil
        destinationFolder = nil
        sourceImages = []
        destinationImages = []
        mappings = []
        destinationSummary = DestinationScanSummary()
        result = nil
        errorMessage = nil
        progress = ReplacementProgress()
        UserDefaults.standard.removeObject(forKey: sourceBookmarkKey)
        UserDefaults.standard.removeObject(forKey: destinationBookmarkKey)
    }

    func reverseSourceOrder() {
        sourceImages.reverse()
        settings.sourceSortMode = .manual
        previewMapping()
    }

    func reverseDestinationOrder() {
        destinationImages.reverse()
        settings.destinationSortMode = .manual
        previewMapping()
    }

    func resetOrder() {
        settings.sourceSortMode = .natural
        settings.destinationSortMode = .natural
        sourceImages = NaturalSortService.sort(sourceImages, mode: settings.sourceSortMode)
        destinationImages = NaturalSortService.sort(destinationImages, mode: settings.destinationSortMode)
        previewMapping()
    }

    func moveSource(from offsets: IndexSet, to destination: Int) {
        sourceImages.move(fromOffsets: offsets, toOffset: destination)
        settings.sourceSortMode = .manual
        previewMapping()
    }

    func moveDestination(from offsets: IndexSet, to destination: Int) {
        destinationImages.move(fromOffsets: offsets, toOffset: destination)
        settings.destinationSortMode = .manual
        previewMapping()
    }

    private func startReplacement(destinationFolder: URL) {
        isReplacing = true
        result = nil
        progress = ReplacementProgress(currentFile: "", currentIndex: 0, total: selectedMappingsCount)
        replacementTask = Task {
            do {
                let replacementResult = try await replacementService.replace(
                    mappings: mappings,
                    destinationFolder: destinationFolder,
                    settings: settings
                ) { progress in
                    await MainActor.run { self.progress = progress }
                }
                await MainActor.run {
                    self.result = replacementResult
                    self.isReplacing = false
                    self.scanFolders()
                }
            } catch {
                await MainActor.run {
                    self.isReplacing = false
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.refreshBackups()
                }
            }
        }
    }

    private func chooseFolder(_ completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    private func saveBookmark(_ url: URL, key: String) {
        if let data = try? bookmarkService.bookmarkData(for: url) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sourceBookmarkKey),
           let url = try? bookmarkService.resolve(data) {
            sourceFolder = url
        }
        if let data = UserDefaults.standard.data(forKey: destinationBookmarkKey),
           let url = try? bookmarkService.resolve(data) {
            destinationFolder = url
            refreshBackups()
        }
    }
}

enum FolderDropTarget {
    case source
    case destination
}
