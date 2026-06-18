import AppKit
import SwiftUI

struct DestinationSelectionView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose Destination Images")
                        .font(.title3.bold())
                    Text(viewModel.destinationSelectionMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.availableSelectedDestinationCount == 0 ? .orange : .secondary)
                }
                Spacer()
                Text("\(viewModel.selectedDestinationCount) checked")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Select All") {
                    viewModel.selectAllDestinations()
                }
                Button("Clear All") {
                    viewModel.clearDestinationSelection()
                }
                Button("Invert Selection") {
                    viewModel.invertDestinationSelection()
                }
                Button("Select First \(viewModel.sourceImages.count)") {
                    viewModel.selectFirstDestinationsMatchingSourceCount()
                }
                .disabled(viewModel.sourceImages.isEmpty)
                Spacer()
                Text("Starting position: \(viewModel.settings.startingPosition)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(viewModel.destinationImages.isEmpty)

            Table(rows) {
                TableColumn("Position") { row in
                    Text("\(row.position)")
                }
                .width(65)

                TableColumn("Replace") { row in
                    Toggle("Replace \(row.image.filename)", isOn: Binding(
                        get: { viewModel.isDestinationSelected(row.image) },
                        set: { viewModel.setDestinationSelected($0, for: row.image) }
                    ))
                    .labelsHidden()
                }
                .width(65)

                TableColumn("Destination Image") { row in
                    DestinationImageCell(file: row.image)
                }

                TableColumn("Extension") { row in
                    Text(row.image.fileExtension.uppercased())
                }
                .width(85)

                TableColumn("Dimensions") { row in
                    Text(row.image.displaySize)
                }
                .width(100)

                TableColumn("Availability") { row in
                    Text(viewModel.destinationSelectionStatus(for: row.image))
                        .foregroundStyle(statusColor(for: row.image))
                }
                .width(125)
            }
            .frame(minHeight: 240, maxHeight: 360)
            .overlay {
                if viewModel.destinationImages.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title)
                        Text("No Destination Images")
                            .font(.headline)
                        Text("Select folders and scan to choose files for replacement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: viewModel.settings.startingPosition) { _ in
            viewModel.previewMapping()
        }
    }

    private var rows: [DestinationSelectionRow] {
        viewModel.orderedDestinationImages.enumerated().map {
            DestinationSelectionRow(position: $0.offset + 1, image: $0.element)
        }
    }

    private func statusColor(for image: ImageFile) -> Color {
        let status = viewModel.destinationSelectionStatus(for: image)
        switch status {
        case "Ready": return .green
        case "Before start", "Selected (unused)": return .orange
        default: return .secondary
        }
    }
}

private struct DestinationSelectionRow: Identifiable {
    let position: Int
    let image: ImageFile

    var id: UUID { image.id }
}

private struct DestinationImageCell: View {
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
