# Image Replacer

Image Replacer is a native macOS app for replacing placeholder image contents in a destination folder with real images from a source folder. Destination filenames, extensions, and paths are preserved exactly.

## Requirements

- macOS 13 or later
- Xcode 15 or later with the macOS SDK
- Swift and SwiftUI
- Git, if cloning from GitHub
- No external runtime, Electron, Python, Node.js, or third-party packages

## Installation

### Install Without Xcode

If you only want to use the app, you do not need Xcode.

#### One-command install

After the repository has a GitHub Release with `Image-Replacer-macOS.zip`, install the app with:

```bash
curl -L https://raw.githubusercontent.com/safiul0073/ImageReplacer/main/scripts/install.sh -o install-image-replacer.sh
chmod +x install-image-replacer.sh
./install-image-replacer.sh safiul0073/ImageReplacer
```

This downloads the latest release zip, unzips `Image Replacer.app`, and installs it into `/Applications`.

#### Manual install

1. Go to the GitHub repository page.
2. Open **Releases**.
3. Download `Image-Replacer-macOS.zip` from the latest release.
4. Unzip the file.
5. Move `Image Replacer.app` to your `Applications` folder.
6. Open the app.

Because this app may be distributed outside the Mac App Store, macOS may show a security warning the first time you open it. If that happens:

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Find the blocked `Image Replacer` message.
4. Click **Open Anyway**.

You can also right-click the app and choose **Open** the first time.

If there is no GitHub release yet, the app has not been packaged for non-Xcode users. The repository owner should create a release tag such as:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will build the app and attach `Image-Replacer-macOS.zip` to the release.

### Build From Source

Building from source requires Xcode. If you do not have Xcode, use the release download above.

### 1. Clone the Repository

```bash
git clone https://github.com/safiul0073/Image-Replacer.git
cd Image-Replacer
```

If you downloaded the project as a ZIP from GitHub, unzip it first, then open the extracted folder.

### 2. Install Xcode

Install Xcode from the Mac App Store or Apple Developer Downloads.

After installing Xcode, open it once so macOS can finish installing required components.

### 3. Select the Xcode Developer Directory

If command-line builds fail with a Command Line Tools message, select the full Xcode developer directory:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

You can verify the active developer directory with:

```bash
xcode-select -p
```

Expected output:

```text
/Applications/Xcode.app/Contents/Developer
```

### 4. Open the Project

Open the project in Xcode:

```bash
open ImageReplacer.xcodeproj
```

Or double-click `ImageReplacer.xcodeproj` in Finder.

### 5. Build and Run in Xcode

1. Select the `ImageReplacer` scheme.
2. Select **My Mac** as the run destination.
3. Press `Command-B` to build.
4. Press `Command-R` to run.

### 6. Build from Terminal

```bash
xcodebuild -project ImageReplacer.xcodeproj -scheme ImageReplacer build
```

Run tests:

```bash
xcodebuild -project ImageReplacer.xcodeproj -scheme ImageReplacer test
```

### 7. Code Signing

For local development, Xcode automatic signing is usually enough.

If Xcode shows a signing error:

1. Select the `ImageReplacer` project in Xcode.
2. Select the `ImageReplacer` app target.
3. Open **Signing & Capabilities**.
4. Enable **Automatically manage signing**.
5. Select your Apple ID team.

For personal local use, a free Apple ID is usually sufficient. Distribution outside your Mac may require an Apple Developer Program account.

### 8. First Run Permissions

On first run, Image Replacer asks you to choose folders through the native macOS folder picker. This is required for sandbox-safe access.

If folder access stops working later, choose the source or destination folder again so the app can refresh its saved permission bookmark.

## Quick Start

1. Open `ImageReplacer.xcodeproj` in Xcode.
2. Select the `ImageReplacer` scheme.
3. Press `Command-R`.
4. Choose a source images folder.
5. Choose a destination folder.
6. Click **Scan Folders**.
7. Review the mapping preview.
8. Click **Replace Images**.

## How It Works

1. Choose a source images folder.
2. Choose a destination folder containing placeholder images.
3. Scan the folders.
4. Review the mapping preview.
5. Click **Replace Images**.

The app maps source images to destination images by their current list order:

```text
sourceImages[0] -> availableDestinations[0]
sourceImages[1] -> availableDestinations[1]
sourceImages[2] -> availableDestinations[2]
```

It never renames destination files and never creates extra destination files.

## Destination Matching

By default, all supported image files directly inside the selected destination folder are included.

Supported destination filenames can be anything:

```text
1-450X450.jpg
account.jpg
best.png
avatar-20.jpg
profile_image.webp
user10.png
```

Optional filters can narrow the destination list:

- Filename contains
- Filename starts with
- Filename ends with
- File extension
- Minimum width
- Minimum height
- Maximum width
- Maximum height

When prefix and suffix are empty, all supported destination images are included.

## Choosing Specific Destination Images

After scanning, the **Choose Destination Images** table shows every matching image in the destination folder.

1. Enter part of a filename in **Filter destination filenames** to narrow the table.
2. Use **Select All Results**, **Clear Results**, or **Invert Results** to change only matching files.
3. Check or uncheck individual destination files as needed.
4. Review each file's sorted position and availability status.
5. Check the Mapping Preview to confirm the exact source-to-destination pairs.
6. Click **Replace Images**.

Selection controls include:

- **Select All**
- **Clear All**
- **Invert Selection**
- **Select First Source Count**

When the filename filter is active, bulk selection controls affect only the filtered results. Existing selections outside the filtered results remain unchanged.

If 12 source images and 30 destination images are found, you can check any 12 destination files. Only those checked files are mapped and replaced. Checked files before the configured starting position remain unchanged.

## Choosing Specific Source Images

The **Choose Source Images** table provides the same filename filtering and selection controls for source files:

1. Enter part of a filename in **Filter source filenames**.
2. Use **Select All Results**, **Clear Results**, or **Invert Results**.
3. Check or uncheck individual source files.
4. Review the Mapping Preview before replacing images.

Only selected source images are mapped. Source selections retain the configured source sort order, regardless of the order in which checkboxes were clicked.

## Pairing One Source to One Destination

For exact control, use the **Destination** dropdown in the **Choose Source Images** table.

1. Scan the source and destination folders.
2. Find the source image you want to control.
3. Open that row's **Destination** dropdown.
4. Choose the exact destination image it should replace.
5. Repeat for any other specific pairs.
6. Review **Mapping Preview** before replacing images.

Choosing a destination from a source row automatically marks that source and destination as selected. If the same destination is later chosen for another source, the app moves the manual pair to the latest source so one destination is never assigned twice.

Rows set to **Automatic** still use the existing ordered mapping behavior with the remaining selected destinations. This lets you manually pair only the special cases and let the app fill the rest.

## Sorting

Source and destination sorting are configurable independently.

Source sorting:

- Natural filename order
- Alphabetical A-Z
- Alphabetical Z-A
- Date created: oldest first
- Date created: newest first
- Date modified: oldest first
- Date modified: newest first
- Manual order

Destination sorting:

- Natural filename order
- Alphabetical A-Z
- Alphabetical Z-A
- Number ascending
- Number descending
- Date created: oldest first
- Date created: newest first
- Date modified: oldest first
- Date modified: newest first
- Manual order

Natural sorting uses Finder-like localized standard comparison, so:

```text
image1.jpg
image2.jpg
image10.jpg
```

sorts in that order.

## Starting Position

Starting position is one-based and refers to the sorted destination list position, not a number extracted from a filename.

Example sorted destination list:

```text
1. account.jpg
2. best.jpg
3. image2.jpg
4. image10.jpg
5. last.jpg
```

If starting position is `3`, replacement begins at `image2.jpg`.

## Image Processing

Output dimensions default to `450x450`.

Resize modes:

- Center Crop
- Fit Without Cropping
- Stretch

The output file format follows the destination file extension. If a transparent source image is saved to JPEG, the app places it on a white background.

JPEG quality defaults to `0.9` and can be adjusted from `0.5` to `1.0`.

## Backups

When backups are enabled, Image Replacer creates:

```text
DestinationFolder/.image-replacer-backups/yyyy-MM-dd_HH-mm-ss/
```

Only destination files that will be replaced are copied. A `manifest.json` file records:

- Backup creation date
- Destination folder
- Application version
- Original destination file paths
- Backup file paths
- Source file paths
- Output dimensions
- Resize mode
- JPEG quality

Use **Restore Last Backup** or the backup list to restore previous destination images.

## Source Files

Source files remain unchanged by default.

Optional settings can move or copy successfully used source images into:

```text
SourceFolder/Used/
```

If a file already exists there, Image Replacer generates a safe unique name such as `photo-2.jpg`.

## Security and Sandbox Permissions

Image Replacer uses `NSOpenPanel` for folder selection and security-scoped bookmarks for sandbox-friendly access. If permission is revoked, select the folder again.

The app validates that every destination write stays inside the selected destination folder.

## Supported Formats

```text
jpg
jpeg
png
webp
heic
tiff
bmp
```

Hidden files, `.DS_Store`, subfolders, backup folders, unsupported files, and temporary files are ignored.

## Example Workflow

1. Put 12 new avatar images inside:

   ```text
   ~/Downloads/avatar-images
   ```

2. Select that folder as the source folder.

3. Select this folder as the destination folder:

   ```text
   ~/Projects/my-project/storage/avatar
   ```

4. Leave prefix and suffix filters empty, or set filters if only certain destination files should be included.

5. Set starting position:

   ```text
   1
   ```

6. Preview the mappings.

7. Click **Replace Images**.

Expected result:

- 12 destination images are replaced
- Destination filenames remain unchanged
- Unused destination images remain unchanged
- The original 12 destination images are stored in a backup folder

## Known Limitations

- Command-line build verification requires a full Xcode installation selected as the active developer directory.
- App icon assets are scaffolded locally; production icon artwork can replace the placeholder asset catalog later.
- Manual row reordering uses SwiftUI table/list behavior and may feel different across macOS releases.
