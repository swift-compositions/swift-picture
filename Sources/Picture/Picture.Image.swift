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

        /// The part of a picture the raster is still to be drawn from, by the renderer that draws the image;
        /// nil for an image that holds its pixels.
        public var source: Source?

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
            self.source = nil
        }
    }
}

extension Picture.Image {
    /// The image's pixel at a point of the shape's space.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        guard source == nil else { return .transparent }
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
    /// The part of a picture inside a rectangle, to be drawn once and kept as an image that stands where that
    /// part stood, so that it can be shown again, moved and repeated, for the price of an image.
    ///
    /// The image holds no pixels yet: it names its `source`, and the renderer that draws a picture holding the
    /// image draws the source first, when and where it chooses, and may keep the result for the next picture
    /// that holds an equal source. The raster will have `scale` pixels to a unit of the picture, rounded up to
    /// whole pixels along each side; with more than one `samples` the picture is drawn that many times as
    /// fine along each side and every pixel is the mean of its square of samples. The placement puts the
    /// raster's first corner at the rectangle's and one pixel at one part in `scale` of a unit.
    public init(
        _ picture: Picture,
        in rectangle: Picture.Plane.Rectangle,
        scale: Double,
        samples: Cardinal = 1,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
    ) {
        let source = Source(picture, in: rectangle, scale: scale, samples: samples)
        self.init(Raster(width: .zero, height: .zero, repeating: .transparent), placement: source.placement, sampling: sampling, edge: edge)
        self.source = source
    }

    /// This image holding its pixels: its source drawn by a renderer, and no source left. An image that
    /// holds its pixels already is given back as it is.
    ///
    /// It fails with `.unsupported` for a rectangle with no area and for a scale that is not positive and
    /// finite, and with the renderer's own error otherwise.
    public func drawn(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Self {
        guard let source else { return self }
        var image = self
        image.raster = try source.raster(through: renderer)
        image.source = nil
        return image
    }

    /// The part of a picture inside a rectangle, drawn now by a renderer and kept as an image that holds its
    /// pixels: `init(_:in:scale:samples:sampling:edge:)` and then `drawn(through:)`.
    public init(
        _ picture: borrowing Picture,
        in rectangle: Picture.Plane.Rectangle,
        scale: Double,
        samples: Cardinal = 1,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent),
        through renderer: Picture.Renderer
    ) throws(Picture.Renderer.Error) {
        self = try Self(copy picture, in: rectangle, scale: scale, samples: samples, sampling: sampling, edge: edge).drawn(through: renderer)
    }
}
