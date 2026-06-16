import SwiftUI

struct ReplacementProgressView: View {
    @EnvironmentObject private var viewModel: ImageReplacementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Replacing Images", systemImage: "arrow.right")
                    .font(.headline)
                Spacer()
                Button("Cancel", role: .destructive) {
                    viewModel.cancelReplacement()
                }
            }
            Text("\(viewModel.progress.currentIndex) of \(viewModel.progress.total): \(viewModel.progress.currentFile)")
                .foregroundStyle(.secondary)
            SwiftUI.ProgressView(value: viewModel.progress.percent)
            Text("\(Int(viewModel.progress.percent * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

