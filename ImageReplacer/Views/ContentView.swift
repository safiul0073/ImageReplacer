import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderView()
                    FolderSelectionView()
                    SettingsView()
                    SourceSelectionView()
                    DestinationSelectionView()
                    MappingPreviewView()
                    if viewModel.isReplacing {
                        ReplacementProgressView()
                    }
                    if viewModel.result != nil {
                        CompletionView()
                    }
                    BackupListView()
                }
                .padding(24)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .alert("Image Replacer", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog(
            "Replace \(viewModel.selectedMappingsCount) images?",
            isPresented: $viewModel.showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace \(viewModel.selectedMappingsCount) Images", role: .destructive) {
                viewModel.confirmReplacement()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            ConfirmationMessage()
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        List {
            Label("Folders", systemImage: "folder")
            Label("Settings", systemImage: "slider.horizontal.3")
            Label("Preview", systemImage: "photo.on.rectangle")
            Label("Backups", systemImage: "externaldrive")
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(viewModel.mappings.filter(\.include).count) ready")
                    .font(.headline)
                Text("Destination names stay unchanged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 34))
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 3) {
                Text(Constants.appName)
                    .font(.largeTitle.bold())
                Text("Replace destination image contents while preserving every filename.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ConfirmationMessage: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        let first = viewModel.mappings.first(where: \.include)?.destination.filename ?? "None"
        let last = viewModel.mappings.last(where: \.include)?.destination.filename ?? "None"
        Text("""
        Source:
        \(viewModel.sourceFolder?.path ?? "Not selected")

        Selected sources:
        \(viewModel.selectedSourceCount)

        Destination:
        \(viewModel.destinationFolder?.path ?? "Not selected")

        Selected destinations:
        \(viewModel.availableSelectedDestinationCount)

        Starting destination:
        \(first)

        Ending destination:
        \(last)

        Backup:
        \(viewModel.settings.createBackup ? "Enabled" : "Disabled")

        This action will overwrite selected destination images while keeping their filenames.
        """)
    }
}
