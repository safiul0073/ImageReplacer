import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageProcessingService {
    func process(sourceURL: URL, destinationURL: URL, targetSize: CGSize, resizeMode: ResizeMode, jpegQuality: Double, jpegBackground: NSColor = .white) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: true] as CFDictionary) else {
            throw AppError.cannotReadSourceImage(sourceURL.lastPathComponent)
        }

        let extensionName = destinationURL.normalizedExtension
        guard let outputType = UTType.imageOutputType(forExtension: extensionName) else {
            throw AppError.unsupportedImageFormat(extensionName)
        }

        guard let rendered = render(image: image, targetSize: targetSize, resizeMode: resizeMode, flattensTransparency: extensionName == "jpg" || extensionName == "jpeg", background: jpegBackground) else {
            throw AppError.cannotReadSourceImage(sourceURL.lastPathComponent)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, outputType.identifier as CFString, 1, nil) else {
            throw AppError.unsupportedImageFormat(extensionName)
        }

        var properties: [CFString: Any] = [:]
        if outputType == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = max(0.5, min(1.0, jpegQuality))
        }
        CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw AppError.cannotWriteDestinationImage(destinationURL.lastPathComponent)
        }
        return data as Data
    }

    func render(image: CGImage, targetSize: CGSize, resizeMode: ResizeMode, flattensTransparency: Bool, background: NSColor = .white) -> CGImage? {
        let width = Int(targetSize.width.rounded())
        let height = Int(targetSize.height.rounded())
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }

        let canvas = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        if flattensTransparency || resizeMode == .aspectFit {
            context.setFillColor(background.cgColor)
            context.fill(canvas)
        }

        let sourceSize = CGSize(width: image.width, height: image.height)
        let drawRect = Self.drawRect(sourceSize: sourceSize, targetSize: targetSize, resizeMode: resizeMode)
        context.interpolationQuality = .high
        context.draw(image, in: drawRect)
        return context.makeImage()
    }

    static func drawRect(sourceSize: CGSize, targetSize: CGSize, resizeMode: ResizeMode) -> CGRect {
        switch resizeMode {
        case .stretch:
            return CGRect(origin: .zero, size: targetSize)
        case .centerCrop:
            let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
            let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            return CGRect(x: (targetSize.width - size.width) / 2, y: (targetSize.height - size.height) / 2, width: size.width, height: size.height)
        case .aspectFit:
            let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
            let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            return CGRect(x: (targetSize.width - size.width) / 2, y: (targetSize.height - size.height) / 2, width: size.width, height: size.height)
        }
    }
}

