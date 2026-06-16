import SwiftUI
import UniformTypeIdentifiers

struct FolderSelectionView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                FolderCard(
                    title: "Source Images Folder",
                    icon: "folder.badge.plus",
                    path: viewModel.sourceFolder?.path,
                    countText: "\(viewModel.sourceImages.count) valid images found",
                    browseAction: viewModel.selectSourceFolder,
                    dropTarget: .source
                )
                FolderCard(
                    title: "Placeholder Destination Folder",
                    icon: "folder",
                    path: viewModel.destinationFolder?.path,
                    countText: "\(viewModel.destinationImages.count) images included after filtering",
                    browseAction: viewModel.selectDestinationFolder,
                    dropTarget: .destination
                )
            }
        }
    }
}

private struct FolderCard: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel
    let title: String
    let icon: String
    let path: String?
    let countText: String
    let browseAction: () -> Void
    let dropTarget: FolderDropTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
                Button("Browse", action: browseAction)
            }
            Text(path ?? "Drop a folder here or choose Browse")
                .lineLimit(2)
                .truncationMode(.middle)
                .foregroundStyle(path == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(countText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .onDrop(of: [UTType.fileURL.identifier, UTType.folder.identifier], isTargeted: nil) { providers in
            viewModel.acceptDroppedFolder(providers, destination: dropTarget)
        }
        .accessibilityElement(children: .combine)
    }
}

