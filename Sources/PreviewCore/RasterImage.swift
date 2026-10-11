import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

public struct RasterImage {
    public let image: CGImage
    public init(image: CGImage) { self.image = image }
    public init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16384, height <= 16384,
              width * height <= 40_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary) else { throw PreviewError.unreadable }
        self.image = image
    }
    private func render(_ input: CIImage, bounds: CGRect) throws -> RasterImage {
        guard let output = CIContext().createCGImage(input, from: bounds) else { throw PreviewError.exportFailed }
        return RasterImage(image: output)
    }
    public func crop(_ rect: CGRect) throws -> RasterImage {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy({ $0.isFinite }),
              rect.width >= 1, rect.height >= 1, bounds.contains(rect),
              let output = image.cropping(to: rect.integral) else { throw PreviewError.invalidPage }
        return RasterImage(image: output)
    }
    public func resize(width: Int, height: Int) throws -> RasterImage {
        guard width > 0, height > 0, width <= 16384, height <= 16384, width * height <= 40_000_000 else {
            throw PreviewError.invalidPage
        }
        let input = CIImage(cgImage: image).transformed(by: CGAffineTransform(
            scaleX: CGFloat(width) / CGFloat(image.width), y: CGFloat(height) / CGFloat(image.height)))
        return try render(input, bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }
    public func flip(horizontal: Bool) throws -> RasterImage {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let transform = horizontal ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
                                   : CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        return try render(CIImage(cgImage: image).transformed(by: transform),
                          bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }
    public func adjust(exposure: Double, contrast: Double, saturation: Double) throws -> RasterImage {
        guard exposure.isFinite, contrast.isFinite, saturation.isFinite,
              (-3...3).contains(exposure), (0...3).contains(contrast), (0...3).contains(saturation) else {
            throw PreviewError.invalidPage
        }
        let input = CIImage(cgImage: image)
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: contrast, kCIInputSaturationKey: saturation])
        return try render(input, bounds: input.extent)
    }
    public func export(to url: URL, type: UTType, quality: Double = 0.9) throws {
        guard [.png, .jpeg, .tiff, .heic].contains(type), quality.isFinite, (0...1).contains(quality) else {
            throw PreviewError.exportFailed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw PreviewError.exportFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PreviewError.exportFailed }
        try (data as Data).write(to: url, options: .atomic)
    }
}
