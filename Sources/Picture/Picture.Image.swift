public import Matrix
public import Raster

extension Picture {
    /// A raster of working pixels placed in a shape's space.
    public struct Image: Sendable, Hashable {
        public var raster: Raster<Picture.Pixel>

        /// Where the raster stands: a projective map of the plane from the raster's own space, one unit a
        /// pixel, into the shape's. An affine placement, whose last row is (0, 0, 1), moves the image as a
        /// group's transform moves its content; any other shows it in perspective, as a card seen at a slant.
        public var placement: Matrix<3, 3, Double>
        public var sampling: Raster<Picture.Pixel>.Sampling
        public var edge: Raster<Picture.Pixel>.Edge

        /// The part of a picture the raster is still to be drawn from, by the renderer that draws the image;
        /// nil for an image that holds its pixels.
        public var source: Source?

        public init(
            _ raster: Raster<Picture.Pixel>,
            placement: Matrix<3, 3, Double> = .identity,
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
    /// An image under an affine placement: `init(_:placement:sampling:edge:)` of the placement's lift.
    public init(
        _ raster: Raster<Picture.Pixel>,
        placement: Picture.Transform,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
    ) {
        self.init(raster, placement: Matrix<3, 3, Double>(placement), sampling: sampling, edge: edge)
    }

    /// The image's pixel at a point of the shape's space. A renderer that reads many pixels of one image reads
    /// them from its `sampler`, which inverts the placement once.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        sampler.pixel(at: point)
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
        self.init(Raster(width: .zero, height: .zero, repeating: .transparent), placement: Matrix<3, 3, Double>(source.placement), sampling: sampling, edge: edge)
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
