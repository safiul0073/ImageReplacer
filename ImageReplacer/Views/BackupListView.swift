import SwiftUI

struct BackupListView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Previous Backups")
                    .font(.title3.bold())
                Spacer()
                Button("Refresh") { viewModel.refreshBackups() }
            }
            if viewModel.availableBackups.isEmpty {
                Text("No backups found for the selected destination folder.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.availableBackups, id: \.self) { backup in
                    HStack {
                        Image(systemName: "externaldrive")
                        Text(backup.lastPathComponent)
                        Spacer()
                        Button("Restore") {
                            viewModel.restoreBackup(at: backup)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

