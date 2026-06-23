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
    @Published private(set) var selectedSourcePaths: Set<String> = []
    @Published private(set) var selectedDestinationPaths: Set<String> = []
    @Published private(set) var assignedDestinationBySourcePath: [String: String] = [:]
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
    private var knownSourcePaths: Set<String> = []
    private var selectionSourceFolderPath: String?
    private var knownDestinationPaths: Set<String> = []
    private var selectionDestinationFolderPath: String?
    private let settingsKey = "appSettings"
    private let sourceBookmarkKey = "sourceFolderBookmark"
    private let destinationBookmarkKey = "destinationFolderBookmark"

    init() {
        loadPersistedState()
    }

    var canPreview: Bool {
        sourceFolder != nil && destinationFolder != nil && selectedSourceCount > 0 && availableSelectedDestinationCount > 0
    }

    var canReplace: Bool {
        !isReplacing && mappings.contains { $0.include }
    }

    var selectedMappingsCount: Int {
        mappings.filter(\.include).count
    }

    var orderedSourceImages: [ImageFile] {
        NaturalSortService.sort(sourceImages, mode: settings.sourceSortMode)
    }

    var selectedSourceCount: Int {
        sourceImages.filter { selectedSourcePaths.contains(imagePath(for: $0)) }.count
    }

    var sourceSelectionMessage: String {
        if sourceImages.isEmpty { return "Scan folders to choose source images." }
        if selectedSourceCount == 0 { return "Select at least one source image to replace a destination." }
        return "\(selectedSourceCount) source images selected."
    }

    var orderedDestinationImages: [ImageFile] {
        NaturalSortService.sort(destinationImages, mode: settings.destinationSortMode)
    }

    var selectedDestinationCount: Int {
        destinationImages.filter { selectedDestinationPaths.contains(destinationPath(for: $0)) }.count
    }

    var availableSelectedDestinationCount: Int {
        availableDestinationImages.filter { selectedDestinationPaths.contains(destinationPath(for: $0)) }.count
    }

    var unusedSelectedDestinationCount: Int {
        max(0, availableSelectedDestinationCount - mappedDestinationCount)
    }

    var explicitPairCount: Int {
        validExplicitPairs().count
    }

    private var mappedDestinationCount: Int {
        previewPairs().count
    }

    var destinationSelectionMessage: String {
        if destinationImages.isEmpty { return "Scan folders to choose destination images." }
        if availableSelectedDestinationCount == 0 { return "Select at least one destination image at or after the starting position." }
        return "\(availableSelectedDestinationCount) selected and available; \(min(selectedSourceCount, availableSelectedDestinationCount)) will be mapped."
    }

    var availableDestinationChoices: [ImageFile] {
        availableDestinationImages
    }

    private var availableDestinationImages: [ImageFile] {
        Array(orderedDestinationImages.dropFirst(max(0, settings.startingPosition - 1)))
    }

    func selectSourceFolder() {
        chooseFolder { [weak self] url in
            self?.setSourceFolder(url)
            self?.saveBookmark(url, key: self?.sourceBookmarkKey ?? "sourceFolderBookmark")
        }
    }

    func selectDestinationFolder() {
        chooseFolder { [weak self] url in
            self?.setDestinationFolder(url)
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
                    self?.setSourceFolder(url)
                    self?.saveBookmark(url, key: self?.sourceBookmarkKey ?? "sourceFolderBookmark")
                case .destination:
                    self?.setDestinationFolder(url)
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
                    self.applyScannedSourceImages(source, in: sourceFolder)
                    self.applyScannedDestinationImages(destination.images, in: destinationFolder)
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
        let sortedDestinations = orderedDestinationImages
        guard settings.startingPosition <= max(1, sortedDestinations.count) else {
            errorMessage = AppError.invalidStartingPosition.localizedDescription
            mappings = []
            return
        }
        let pairs = previewPairs()
        mappings = pairs.enumerated().map {
            ReplacementMapping(order: $0.offset + 1, source: $0.element.source, destination: $0.element.destination)
        }
        destinationSummary.availableAfterStartingPosition = availableSelectedDestinationCount
    }

    func applyScannedDestinationImages(_ images: [ImageFile], in folder: URL) {
        destinationImages = NaturalSortService.sort(images, mode: settings.destinationSortMode)
        updateDestinationSelection(afterScanning: destinationImages, in: folder)
    }

    func applyScannedSourceImages(_ images: [ImageFile], in folder: URL) {
        sourceImages = NaturalSortService.sort(images, mode: settings.sourceSortMode)
        updateSourceSelection(afterScanning: sourceImages, in: folder)
    }

    func isSourceSelected(_ image: ImageFile) -> Bool {
        selectedSourcePaths.contains(imagePath(for: image))
    }

    func setSourceSelected(_ selected: Bool, for image: ImageFile) {
        let path = imagePath(for: image)
        if selected {
            selectedSourcePaths.insert(path)
        } else {
            selectedSourcePaths.remove(path)
            assignedDestinationBySourcePath.removeValue(forKey: path)
        }
        previewMapping()
    }

    func selectAllSources(in images: [ImageFile]? = nil) {
        selectedSourcePaths.formUnion((images ?? sourceImages).map { imagePath(for: $0) })
        previewMapping()
    }

    func clearSourceSelection(in images: [ImageFile]? = nil) {
        let paths = (images ?? sourceImages).map { imagePath(for: $0) }
        selectedSourcePaths.subtract(paths)
        for path in paths {
            assignedDestinationBySourcePath.removeValue(forKey: path)
        }
        previewMapping()
    }

    func invertSourceSelection(in images: [ImageFile]? = nil) {
        for image in images ?? sourceImages {
            let path = imagePath(for: image)
            if selectedSourcePaths.contains(path) {
                selectedSourcePaths.remove(path)
                assignedDestinationBySourcePath.removeValue(forKey: path)
            } else {
                selectedSourcePaths.insert(path)
            }
        }
        previewMapping()
    }

    func assignedDestinationPath(for source: ImageFile) -> String {
        assignedDestinationBySourcePath[imagePath(for: source)] ?? ""
    }

    func assignedDestinationFilename(for source: ImageFile) -> String {
        guard let path = assignedDestinationBySourcePath[imagePath(for: source)] else { return "Automatic" }
        return destinationImage(forPath: path)?.filename ?? "Missing destination"
    }

    func setAssignedDestinationPath(_ destinationPath: String, for source: ImageFile) {
        let sourcePath = imagePath(for: source)
        guard !destinationPath.isEmpty else {
            assignedDestinationBySourcePath.removeValue(forKey: sourcePath)
            previewMapping()
            return
        }
        guard let destination = destinationImage(forPath: destinationPath),
              isDestinationAvailable(destination) else {
            assignedDestinationBySourcePath.removeValue(forKey: sourcePath)
            previewMapping()
            return
        }

        for (otherSourcePath, assignedPath) in assignedDestinationBySourcePath where assignedPath == destinationPath && otherSourcePath != sourcePath {
            assignedDestinationBySourcePath.removeValue(forKey: otherSourcePath)
        }
        selectedSourcePaths.insert(sourcePath)
        selectedDestinationPaths.insert(destinationPath)
        assignedDestinationBySourcePath[sourcePath] = destinationPath
        previewMapping()
    }

    func clearExplicitPair(for source: ImageFile) {
        assignedDestinationBySourcePath.removeValue(forKey: imagePath(for: source))
        previewMapping()
    }

    func isDestinationSelected(_ image: ImageFile) -> Bool {
        selectedDestinationPaths.contains(destinationPath(for: image))
    }

    func isDestinationAvailable(_ image: ImageFile) -> Bool {
        guard let index = orderedDestinationImages.firstIndex(where: { destinationPath(for: $0) == destinationPath(for: image) }) else {
            return false
        }
        return index >= max(0, settings.startingPosition - 1)
    }

    func destinationSelectionStatus(for image: ImageFile) -> String {
        guard isDestinationAvailable(image) else { return "Before start" }
        guard isDestinationSelected(image) else { return "Not selected" }
        let selectedAvailable = availableDestinationImages.filter { isDestinationSelected($0) }
        guard let selectedIndex = selectedAvailable.firstIndex(where: { destinationPath(for: $0) == destinationPath(for: image) }) else {
            return "Selected"
        }
        return selectedIndex < selectedSourceCount ? "Ready" : "Selected (unused)"
    }

    func setDestinationSelected(_ selected: Bool, for image: ImageFile) {
        let path = destinationPath(for: image)
        if selected {
            selectedDestinationPaths.insert(path)
        } else {
            selectedDestinationPaths.remove(path)
            removeAssignments(toDestinationPath: path)
        }
        previewMapping()
    }

    func selectAllDestinations(in images: [ImageFile]? = nil) {
        let targets = images ?? destinationImages
        selectedDestinationPaths.formUnion(targets.map { destinationPath(for: $0) })
        previewMapping()
    }

    func clearDestinationSelection(in images: [ImageFile]? = nil) {
        let targets = images ?? destinationImages
        let paths = targets.map { destinationPath(for: $0) }
        selectedDestinationPaths.subtract(paths)
        for path in paths {
            removeAssignments(toDestinationPath: path)
        }
        previewMapping()
    }

    func invertDestinationSelection(in images: [ImageFile]? = nil) {
        for image in images ?? destinationImages {
            let path = destinationPath(for: image)
            if selectedDestinationPaths.contains(path) {
                selectedDestinationPaths.remove(path)
                removeAssignments(toDestinationPath: path)
            } else {
                selectedDestinationPaths.insert(path)
            }
        }
        previewMapping()
    }

    func selectFirstDestinationsMatchingSourceCount(in images: [ImageFile]? = nil) {
        let targets = images ?? destinationImages
        let targetPaths = Set(targets.map { destinationPath(for: $0) })
        selectedDestinationPaths.subtract(targetPaths)
        for path in targetPaths {
            removeAssignments(toDestinationPath: path)
        }
        let availableTargets = availableDestinationImages.filter { targetPaths.contains(destinationPath(for: $0)) }
        selectedDestinationPaths.formUnion(availableTargets.prefix(selectedSourceCount).map { destinationPath(for: $0) })
        previewMapping()
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
        resetSourceSelection()
        resetDestinationSelection()
        assignedDestinationBySourcePath = [:]
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
        let replacementService = replacementService
        let mappings = mappings
        let settings = settings
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

    private func setSourceFolder(_ url: URL) {
        let newPath = url.standardizedFileURL.path
        if sourceFolder?.standardizedFileURL.path != newPath {
            resetSourceSelection()
        }
        sourceFolder = url
        selectionSourceFolderPath = newPath
    }

    private func updateSourceSelection(afterScanning images: [ImageFile], in folder: URL) {
        let folderPath = folder.standardizedFileURL.path
        if selectionSourceFolderPath != folderPath {
            resetSourceSelection()
            selectionSourceFolderPath = folderPath
        }

        let currentPaths = Set(images.map { imagePath(for: $0) })
        if knownSourcePaths.isEmpty {
            selectedSourcePaths.formUnion(currentPaths)
        }
        selectedSourcePaths.formIntersection(currentPaths)
        assignedDestinationBySourcePath = assignedDestinationBySourcePath.filter { currentPaths.contains($0.key) }
        knownSourcePaths.formUnion(currentPaths)
    }

    private func resetSourceSelection() {
        selectedSourcePaths = []
        knownSourcePaths = []
        selectionSourceFolderPath = nil
        assignedDestinationBySourcePath = [:]
        mappings = []
    }

    private func setDestinationFolder(_ url: URL) {
        let newPath = url.standardizedFileURL.path
        if destinationFolder?.standardizedFileURL.path != newPath {
            resetDestinationSelection()
        }
        destinationFolder = url
        selectionDestinationFolderPath = newPath
    }

    private func updateDestinationSelection(afterScanning images: [ImageFile], in folder: URL) {
        let folderPath = folder.standardizedFileURL.path
        if selectionDestinationFolderPath != folderPath {
            resetDestinationSelection()
            selectionDestinationFolderPath = folderPath
        }

        let currentPaths = Set(images.map { destinationPath(for: $0) })
        if knownDestinationPaths.isEmpty {
            selectedDestinationPaths.formUnion(currentPaths)
        }
        selectedDestinationPaths.formIntersection(currentPaths)
        assignedDestinationBySourcePath = assignedDestinationBySourcePath.filter { currentPaths.contains($0.value) }
        knownDestinationPaths.formUnion(currentPaths)
    }

    private func resetDestinationSelection() {
        selectedDestinationPaths = []
        knownDestinationPaths = []
        selectionDestinationFolderPath = nil
        assignedDestinationBySourcePath = [:]
        mappings = []
    }

    private func previewPairs() -> [(source: ImageFile, destination: ImageFile)] {
        let sortedSources = orderedSourceImages.filter { selectedSourcePaths.contains(imagePath(for: $0)) }
        let selectedAvailableDestinations = availableDestinationImages.filter { selectedDestinationPaths.contains(destinationPath(for: $0)) }
        let validPairs = validExplicitPairs()
        let explicitlyUsedSourcePaths = Set(validPairs.keys)
        let explicitlyUsedDestinationPaths = Set(validPairs.values)

        var pairs: [(source: ImageFile, destination: ImageFile)] = []
        var remainingDestinations = selectedAvailableDestinations.filter {
            !explicitlyUsedDestinationPaths.contains(destinationPath(for: $0))
        }

        for source in sortedSources {
            let sourcePath = imagePath(for: source)
            if let destinationPath = validPairs[sourcePath],
               let destination = destinationImage(forPath: destinationPath) {
                pairs.append((source, destination))
            } else if !explicitlyUsedSourcePaths.contains(sourcePath), !remainingDestinations.isEmpty {
                pairs.append((source, remainingDestinations.removeFirst()))
            }
        }

        return pairs
    }

    private func validExplicitPairs() -> [String: String] {
        let sourcePaths = Set(orderedSourceImages.filter { selectedSourcePaths.contains(imagePath(for: $0)) }.map { imagePath(for: $0) })
        let availableDestinationPaths = Set(availableDestinationImages.filter { selectedDestinationPaths.contains(destinationPath(for: $0)) }.map { destinationPath(for: $0) })
        var usedDestinations = Set<String>()
        var valid: [String: String] = [:]

        for source in orderedSourceImages {
            let sourcePath = imagePath(for: source)
            guard sourcePaths.contains(sourcePath),
                  let destinationPath = assignedDestinationBySourcePath[sourcePath],
                  availableDestinationPaths.contains(destinationPath),
                  !usedDestinations.contains(destinationPath) else {
                continue
            }
            valid[sourcePath] = destinationPath
            usedDestinations.insert(destinationPath)
        }

        return valid
    }

    private func destinationImage(forPath path: String) -> ImageFile? {
        destinationImages.first { destinationPath(for: $0) == path }
    }

    private func removeAssignments(toDestinationPath path: String) {
        assignedDestinationBySourcePath = assignedDestinationBySourcePath.filter { $0.value != path }
    }

    private func destinationPath(for image: ImageFile) -> String {
        imagePath(for: image)
    }

    private func imagePath(for image: ImageFile) -> String {
        image.url.standardizedFileURL.path
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
            selectionSourceFolderPath = url.standardizedFileURL.path
        }
        if let data = UserDefaults.standard.data(forKey: destinationBookmarkKey),
           let url = try? bookmarkService.resolve(data) {
            destinationFolder = url
            selectionDestinationFolderPath = url.standardizedFileURL.path
            refreshBackups()
        }
    }
}

enum FolderDropTarget {
    case source
    case destination
}
