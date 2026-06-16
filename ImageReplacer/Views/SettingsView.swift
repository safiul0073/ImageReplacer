import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filename Filters")
                .font(.title3.bold())
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    TextField("Filename prefix", text: $viewModel.settings.filenamePrefix)
                    TextField("Filename suffix", text: $viewModel.settings.filenameSuffix)
                    TextField("Filename contains", text: $viewModel.settings.filenameContains)
                    TextField("File extension", text: $viewModel.settings.fileExtension)
                }
                GridRow {
                    IntegerField(title: "Minimum width", value: $viewModel.settings.minimumWidth)
                    IntegerField(title: "Minimum height", value: $viewModel.settings.minimumHeight)
                    IntegerField(title: "Maximum width", value: $viewModel.settings.maximumWidth)
                    IntegerField(title: "Maximum height", value: $viewModel.settings.maximumHeight)
                }
            }

            Divider()

            Text("Processing Settings")
                .font(.title3.bold())
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Stepper("Starting position: \(viewModel.settings.startingPosition)", value: $viewModel.settings.startingPosition, in: 1...999_999)
                    Stepper("Width: \(viewModel.settings.width)", value: $viewModel.settings.width, in: 1...10_000)
                    Stepper("Height: \(viewModel.settings.height)", value: $viewModel.settings.height, in: 1...10_000)
                }
                GridRow {
                    Picker("Resize mode", selection: $viewModel.settings.resizeMode) {
                        ForEach(ResizeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Toggle("Use destination image’s existing dimensions", isOn: $viewModel.settings.useDestinationDimensions)
                    VStack(alignment: .leading) {
                        Text("JPEG quality \(viewModel.settings.jpegQuality, specifier: "%.2f")")
                        Slider(value: $viewModel.settings.jpegQuality, in: 0.5...1.0)
                    }
                }
                GridRow {
                    Toggle("Create backup before replacement", isOn: $viewModel.settings.createBackup)
                    Toggle("Show confirmation before replacement", isOn: $viewModel.settings.showConfirmation)
                    Toggle("Move used source images after replacement", isOn: $viewModel.settings.moveUsedSourceImages)
                }
                GridRow {
                    Toggle("Copy used source images instead", isOn: $viewModel.settings.copyUsedSourceImages)
                    Toggle("Overwrite existing backup", isOn: $viewModel.settings.overwriteExistingBackup)
                    Toggle("Preserve image quality", isOn: $viewModel.settings.preserveImageQuality)
                }
            }

            HStack {
                Text("Total destination images found: \(viewModel.destinationSummary.total)")
                Text("Included: \(viewModel.destinationSummary.included)")
                Text("Excluded: \(viewModel.destinationSummary.excluded)")
                Text("Available after start: \(viewModel.destinationSummary.availableAfterStartingPosition)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ActionButtonsView()
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct IntegerField: View {
    let title: String
    @Binding var value: Int?

    var body: some View {
        TextField(title, value: $value, format: .number)
            .textFieldStyle(.roundedBorder)
    }
}

private struct ActionButtonsView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        HStack {
            Button {
                viewModel.scanFolders()
            } label: {
                Label("Scan Folders", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning || viewModel.isReplacing)

            Button {
                viewModel.previewMapping()
            } label: {
                Label("Preview Mapping", systemImage: "photo.on.rectangle")
            }
            .disabled(!viewModel.canPreview)

            Button {
                viewModel.replaceImages()
            } label: {
                Label("Replace Images", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canReplace)

            Button {
                viewModel.restoreLastBackup()
            } label: {
                Label("Restore Last Backup", systemImage: "arrow.uturn.backward")
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.clear()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
        }
    }
}

