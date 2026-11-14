import Picture
import Picture_CPU
import Testing

enum `Picture CPU Tests` {}

extension `Picture CPU Tests` {
    typealias Pixel = Picture.Pixel
    typealias Canvas = Raster<Picture.Pixel>

    static let renderer = Picture.Renderer.cpu

    /// The pixels an image holds; none for an image that is still a drawing.
    static func raster(of image: Picture.Image) -> Raster<Picture.Pixel> {
        guard case .pixels(let raster) = image.content else { return Raster(width: .zero, height: .zero, repeating: .transparent) }
        return raster
    }

    /// The source of an image that is still a drawing, nil for one that holds its pixels.
    static func source(of image: Picture.Image) -> Picture.Image.Source? {
        guard case .drawing(let source) = image.content else { return nil }
        return source
    }

    static func at(_ x: Double, _ y: Double) -> Picture.Plane.Point<2> { .init([x, y]) }

    static func pixel(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float) -> Pixel {
        Pixel(color: .init(red: red, green: green, blue: blue), alpha: alpha)
    }

    static func close(_ a: Pixel, _ b: Pixel, within tolerance: Float = 1e-5) -> Bool {
        abs(a.color.red - b.color.red) <= tolerance && abs(a.color.green - b.color.green) <= tolerance
            && abs(a.color.blue - b.color.blue) <= tolerance && abs(a.alpha - b.alpha) <= tolerance
    }

    static func close(_ a: Canvas, _ b: Canvas, within tolerance: Float = 1e-5) -> Bool {
        a.width == b.width && a.height == b.height && zip(a.pixels, b.pixels).allSatisfy { close($0, $1, within: tolerance) }
    }

    /// A closed rectangle of straight sides, `x` to `x + width` and `y` to `y + height`.
    static func rectangle(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Picture.Plane.Path {
        polygon([at(x, y), at(x + width, y), at(x + width, y + height), at(x, y + height)])
    }

    /// A closed polygon of straight sides through the corners in order.
    static func polygon(_ corners: [Picture.Plane.Point<2>]) -> Picture.Plane.Path {
        let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
            Picture.Plane.Path.Segment.line(.init(start: start, end: end))
        }
        return Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
    }

    static func fill(_ path: Picture.Plane.Path, _ color: Picture.Color, rule: Winding.Rule = .nonzero) -> Picture.Element {
        .shape(Picture.Shape(path, fill: .init(.solid(color), rule: rule)))
    }

    static func canvas(_ width: UInt, _ height: UInt, _ pixel: Pixel = .transparent) -> Canvas {
        Canvas(width: Cardinal(width), height: Cardinal(height), repeating: pixel)
    }

    static func drawn(_ picture: Picture, on canvas: Canvas) throws(Picture.Renderer.Error) -> Canvas {
        var raster = canvas
        try renderer.render(picture, into: &raster)
        return raster
    }

    /// Every pixel position of a raster of a size, in row order.
    static func positions(_ width: UInt, _ height: UInt) -> [(x: UInt, y: UInt)] {
        (0..<height).flatMap { y in (0..<width).map { x in (x: x, y: y) } }
    }

    static func at(_ raster: Canvas, _ x: UInt, _ y: UInt) -> Pixel {
        raster[x: Ordinal(x), y: Ordinal(y)]
    }

    static let red = Picture.Color(red: 1, green: 0, blue: 0)
    static let blue = Picture.Color(red: 0, green: 0, blue: 1)
    static let translucent = Picture.Color(red: 1, green: 0.5, blue: 0, alpha: 0.5)
}
