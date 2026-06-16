import SwiftUI

@main
struct ImageReplacerApp: App {
    @StateObject private var viewModel = ImageReplacementViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1120, minHeight: 760)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Select Source Folder") { viewModel.selectSourceFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Select Destination Folder") { viewModel.selectDestinationFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Scan") { viewModel.scanFolders() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Preview") { viewModel.previewMapping() }
                    .keyboardShortcut("p", modifiers: [.command])
                Button("Replace Images") { viewModel.replaceImages() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!viewModel.canReplace)
                Button("Restore Backup") { viewModel.restoreLastBackup() }
                Divider()
            }

            CommandGroup(after: .pasteboard) {
                Button("Clear Selection") { viewModel.clear() }
            }

            CommandGroup(replacing: .help) {
                Button("How It Works") {
                    showHelpPanel(
                        title: "How It Works",
                        message: "Choose source and destination folders, scan, review the mapping preview, then replace selected destination image contents. Destination filenames and extensions are preserved."
                    )
                }
                Button("Supported Formats") {
                    showHelpPanel(
                        title: "Supported Formats",
                        message: "Image Replacer supports jpg, jpeg, png, webp, heic, tiff, and bmp files. Hidden files, subfolders, backup folders, and unsupported files are ignored."
                    )
                }
                Button("About Image Placeholder Replacer") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: Constants.appName,
                        .applicationVersion: Constants.appVersion
                    ])
                }
            }
        }
    }

    private func showHelpPanel(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
