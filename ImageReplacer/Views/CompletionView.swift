import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        if let result = viewModel.result {
            VStack(alignment: .leading, spacing: 12) {
                Label("Completed", systemImage: result.failed == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.title3.bold())
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        Text("Successfully replaced")
                        Text("\(result.successful)")
                    }
                    GridRow {
                        Text("Failed")
                        Text("\(result.failed)")
                    }
                    GridRow {
                        Text("Skipped")
                        Text("\(result.skipped)")
                    }
                    GridRow {
                        Text("Source files moved/copied")
                        Text("\(result.movedSourceFiles)")
                    }
                    GridRow {
                        Text("Backup folder")
                        Text(result.backupFolder?.path ?? "None")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                HStack {
                    Button("Open Destination Folder") {
                        if let url = viewModel.destinationFolder { NSWorkspace.shared.open(url) }
                    }
                    Button("Open Backup Folder") {
                        if let url = result.backupFolder { NSWorkspace.shared.open(url) }
                    }
                    .disabled(result.backupFolder == nil)
                    Button("Restore Backup") {
                        if let url = result.backupFolder { viewModel.restoreBackup(at: url) }
                    }
                    .disabled(result.backupFolder == nil)
                    Button("Done") {
                        viewModel.result = nil
                    }
                }
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

