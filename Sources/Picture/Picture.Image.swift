import Point
public import Raster
import Vector

extension Picture {
    /// A raster of working pixels placed in a shape's space.
    public struct Image: Sendable, Hashable {
        public var raster: Raster<Picture.Pixel>
        public var placement: Picture.Transform
        public var sampling: Raster<Picture.Pixel>.Sampling
        public var edge: Raster<Picture.Pixel>.Edge

        public init(
            _ raster: Raster<Picture.Pixel>,
            placement: Picture.Transform = .identity,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            self.raster = raster
            self.placement = placement
            self.sampling = sampling
            self.edge = edge
        }
    }
}

extension Picture.Image {
    /// The image's pixel at a point of the shape's space.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        let inverse: Picture.Transform
        do throws(Matrix<2, 3, Double>.Error) { inverse = try placement.inverted() } catch { return .transparent }
        if raster.isEmpty {
            guard case .constant(let pixel) = edge else { return .transparent }
            return pixel
        }
        let source = inverse.applied(to: Vector([point[0], point[1]]))
        guard source[0].isFinite, source[1].isFinite else { return .transparent }
        return raster.sample(at: Point::Point<2, Double>([source[0], source[1]]), sampling, edge: edge) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }
}

extension Picture.Image {
    /// The part of a picture inside a rectangle, drawn once by a renderer and kept as an image that stands
    /// where that part stood, so that it can be drawn again, moved and repeated, for the price of an image.
    ///
    /// The raster has `scale` pixels to a unit of the picture, rounded up to whole pixels along each side,
    /// and starts transparent. With more than one `samples` the picture is drawn that many times as fine
    /// along each side and every pixel is the mean of its square of samples. The placement puts the
    /// raster's first corner at the rectangle's and one pixel at one part in `scale` of a unit.
    ///
    /// It fails with `.unsupported` for a rectangle with no area and for a scale that is not positive and
    /// finite, and with the renderer's own error otherwise.
    public init(
        _ picture: borrowing Picture,
        in rectangle: Picture.Plane.Rectangle,
        scale: Double,
        samples: Cardinal = 1,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent),
        through renderer: Picture.Renderer
    ) throws(Picture.Renderer.Error) {
        let left = rectangle.llx.underlying
        let top = rectangle.lly.underlying
        let across = (rectangle.urx.underlying - left) * scale
        let down = (rectangle.ury.underlying - top) * scale
        let fine = Swift.max(Int(clamping: samples), 1)
        guard scale > 0, scale.isFinite, across > 0, down > 0, across.isFinite, down.isFinite,
            across < Double(Int32.max / Int32(clamping: fine)), down < Double(Int32.max / Int32(clamping: fine))
        else { throw .unsupported }
        let width = Int(across.rounded(.up))
        let height = Int(down.rounded(.up))
        let zoom = scale * Double(fine)
        let moved = Picture.Transform(rows: [[zoom, 0, -left * zoom], [0, zoom, -top * zoom]])
        var raster = Raster<Picture.Pixel>(
            width: Cardinal(UInt(width * fine)),
            height: Cardinal(UInt(height * fine)),
            repeating: .transparent
        )
        try renderer.render([.group(Picture.Group(copy picture, transform: moved))], into: &raster)
        if fine > 1 {
            raster = raster.resampled(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), .box) { (from: Picture.Pixel, to: Picture.Pixel, parameter: Float) in
                from.interpolated(to: to, at: parameter)
            }
        }
        self.init(
            raster,
            placement: Picture.Transform(rows: [[1 / scale, 0, left], [0, 1 / scale, top]]),
            sampling: sampling,
            edge: edge
        )
    }
}
