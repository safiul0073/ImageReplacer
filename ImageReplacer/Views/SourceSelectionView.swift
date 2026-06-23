import AppKit
import SwiftUI

struct SourceSelectionView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel
    @State private var filterText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose Source Images")
                        .font(.title3.bold())
                    Text(viewModel.sourceSelectionMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.selectedSourceCount == 0 ? .orange : .secondary)
                }
                Spacer()
                Text("\(viewModel.selectedSourceCount) checked")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter source filenames", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Filter source filenames")
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear filename filter")
                }
                Text("Showing \(filteredImages.count) of \(viewModel.sourceImages.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 105, alignment: .trailing)
            }

            HStack {
                Button(filterText.isEmpty ? "Select All" : "Select All Results") {
                    viewModel.selectAllSources(in: filteredImages)
                }
                Button(filterText.isEmpty ? "Clear All" : "Clear Results") {
                    viewModel.clearSourceSelection(in: filteredImages)
                }
                Button(filterText.isEmpty ? "Invert Selection" : "Invert Results") {
                    viewModel.invertSourceSelection(in: filteredImages)
                }
                Spacer()
                Text("Mapping uses selected sources in the current source sort order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(filteredImages.isEmpty)

            Table(rows) {
                TableColumn("Position") { row in
                    Text("\(row.position)")
                }
                .width(65)

                TableColumn("Use") { row in
                    Toggle("Use \(row.image.filename)", isOn: Binding(
                        get: { viewModel.isSourceSelected(row.image) },
                        set: { viewModel.setSourceSelected($0, for: row.image) }
                    ))
                    .labelsHidden()
                }
                .width(55)

                TableColumn("Source Image") { row in
                    SourceImageCell(file: row.image)
                }

                TableColumn("Destination") { row in
                    Picker("Destination for \(row.image.filename)", selection: Binding(
                        get: { viewModel.assignedDestinationPath(for: row.image) },
                        set: { viewModel.setAssignedDestinationPath($0, for: row.image) }
                    )) {
                        Text("Automatic").tag("")
                        ForEach(viewModel.availableDestinationChoices) { destination in
                            Text(destination.filename).tag(destination.url.standardizedFileURL.path)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240)
                    .help("Choose the exact destination this source image should replace")
                }
                .width(min: 180, ideal: 230, max: 280)

                TableColumn("Extension") { row in
                    Text(row.image.fileExtension.uppercased())
                }
                .width(85)

                TableColumn("Dimensions") { row in
                    Text(row.image.displaySize)
                }
                .width(100)

                TableColumn("Status") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isSourceSelected(row.image) ? "Selected" : "Not selected")
                            .foregroundStyle(viewModel.isSourceSelected(row.image) ? .green : .secondary)
                        if viewModel.assignedDestinationPath(for: row.image).isEmpty == false {
                            Text("Paired: \(viewModel.assignedDestinationFilename(for: row.image))")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                        }
                    }
                }
                .width(150)
            }
            .frame(minHeight: 220, maxHeight: 340)
            .overlay {
                if rows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.sourceImages.isEmpty ? "photo.badge.plus" : "magnifyingglass")
                            .font(.title)
                        Text(viewModel.sourceImages.isEmpty ? "No Source Images" : "No Matching Sources")
                            .font(.headline)
                        Text(viewModel.sourceImages.isEmpty ? "Select folders and scan to choose source files." : "Try a different filename filter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var rows: [SourceSelectionRow] {
        viewModel.orderedSourceImages.enumerated().compactMap { item in
            guard filterText.nilIfBlank == nil || item.element.filename.localizedCaseInsensitiveContains(filterText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return SourceSelectionRow(position: item.offset + 1, image: item.element)
        }
    }

    private var filteredImages: [ImageFile] {
        rows.map(\.image)
    }
}

private struct SourceSelectionRow: Identifiable {
    let position: Int
    let image: ImageFile

    var id: UUID { image.id }
}

private struct SourceImageCell: View {
    let file: ImageFile
    @State private var image: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(file.filename)
                .lineLimit(1)
        }
        .task(id: file.url) {
            guard let data = await Task.detached(priority: .utility, operation: {
                try? Data(contentsOf: file.url)
            }).value else { return }
            let thumbnail = NSImage(data: data)
            thumbnail?.size = NSSize(width: 48, height: 48)
            image = thumbnail
        }
    }
}
