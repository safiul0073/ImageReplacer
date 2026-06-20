import AppKit
import SwiftUI

struct MappingPreviewView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mapping Preview")
                    .font(.title3.bold())
                Spacer()
                Text("\(viewModel.selectedMappingsCount) will be replaced")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Picker("Source sorting", selection: $viewModel.settings.sourceSortMode) {
                    ForEach(ImageSortMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .onChange(of: viewModel.settings.sourceSortMode) { _ in viewModel.previewMapping() }

                Picker("Destination sorting", selection: $viewModel.settings.destinationSortMode) {
                    ForEach(DestinationSortMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .onChange(of: viewModel.settings.destinationSortMode) { _ in viewModel.previewMapping() }

                Button("Reverse Source") { viewModel.reverseSourceOrder() }
                Button("Reverse Destination") { viewModel.reverseDestinationOrder() }
                Button("Reset Order") { viewModel.resetOrder() }
            }

            Table($viewModel.mappings) {
                TableColumn("Order") { $mapping in
                    Text("\(mapping.order)")
                }
                .width(50)
                TableColumn("Include") { $mapping in
                    Toggle("", isOn: $mapping.include)
                        .labelsHidden()
                }
                .width(60)
                TableColumn("Source") { $mapping in
                    ImageCell(file: mapping.source)
                }
                TableColumn("Destination") { $mapping in
                    ImageCell(file: mapping.destination)
                }
                TableColumn("Extension") { $mapping in
                    Text(mapping.destination.fileExtension.uppercased())
                }
                .width(90)
                TableColumn("Status") { $mapping in
                    Text(mapping.status.rawValue)
                        .foregroundStyle(mapping.status == .failed ? .red : .secondary)
                }
                .width(100)
            }
            .frame(minHeight: 260)

            HStack {
                Text("Total source images: \(viewModel.sourceImages.count)")
                Text("Selected sources: \(viewModel.selectedSourceCount)")
                Text("Total destination matches: \(viewModel.destinationImages.count)")
                Text("Selected destinations: \(viewModel.availableSelectedDestinationCount)")
                Text("Unused selected sources: \(max(0, viewModel.selectedSourceCount - viewModel.mappings.count))")
                Text("Unused selected destinations: \(viewModel.unusedSelectedDestinationCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ImageCell: View {
    let file: ImageFile

    var body: some View {
        HStack(spacing: 8) {
            ThumbnailView(url: file.url)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .lineLimit(1)
                Text(file.displaySize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
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
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: url) {
            if let data = await loadThumbnailData() {
                let thumbnail = NSImage(data: data)
                thumbnail?.size = NSSize(width: 48, height: 48)
                image = thumbnail
            }
        }
    }

    private func loadThumbnailData() async -> Data? {
        await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
    }
}
