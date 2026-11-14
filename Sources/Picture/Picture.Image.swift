public import Matrix
public import Raster

extension Picture {
    /// A raster of working pixels placed in a shape's space, or the drawing it is still to be drawn from.
    ///
    /// An image's identity is cheap: an image that holds pixels hashes them once, the first time it is hashed or
    /// compared, and keeps that number for all its copies; an image with a drawing is its source, hashed once
    /// when it was made from the source's value, never from pixels.
    public struct Image: Sendable {
        /// What the image shows: its pixels, kept with the hash of their values, or the drawing they are still to
        /// be drawn from.
        var stored: Stored

        /// Where the raster stands: a projective map of the plane from the raster's own space, one unit a
        /// pixel, into the shape's. An affine placement, whose last row is (0, 0, 1), moves the image as a
        /// group's transform moves its content; any other shows it in perspective, as a card seen at a slant.
        public var placement: Matrix<3, 3, Double>
        public var sampling: Raster<Picture.Pixel>.Sampling
        public var edge: Raster<Picture.Pixel>.Edge

        public init(
            _ raster: Raster<Picture.Pixel>,
            placement: Matrix<3, 3, Double> = .identity,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            self.stored = .pixels(Held(raster))
            self.placement = placement
            self.sampling = sampling
            self.edge = edge
        }
    }
}

extension Picture.Image {
    /// What the image shows: the pixels it holds, or the drawing a renderer draws them from. A drawing paints
    /// nothing until a renderer has turned it into pixels.
    public var content: Content {
        get {
            switch stored {
            case .pixels(let held): .pixels(held.raster)
            case .drawing(let source): .drawing(source)
            }
        }
        set {
            switch newValue {
            case .pixels(let raster): stored = .pixels(Held(raster))
            case .drawing(let source): stored = .drawing(source)
            }
        }
    }

    /// An image that holds no pixels yet and names a drawing as its source, under a placement of the raster the
    /// drawing will draw.
    public init(
        _ drawing: some Drawing,
        placement: Matrix<3, 3, Double>,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
    ) {
        self.init(Raster(width: .zero, height: .zero, repeating: .transparent), placement: placement, sampling: sampling, edge: edge)
        self.stored = .drawing(Source(drawing))
    }

    /// An image naming a drawing, under an affine placement: `init(_:placement:sampling:edge:)` of the placement's lift.
    public init(
        _ drawing: some Drawing,
        placement: Picture.Transform,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
    ) {
        self.init(drawing, placement: Matrix<3, 3, Double>(placement), sampling: sampling, edge: edge)
    }
}

extension Picture.Image: Hashable {
    public static func == (first: Self, second: Self) -> Bool {
        guard first.placement == second.placement, first.sampling == second.sampling, first.edge == second.edge else { return false }
        switch (first.stored, second.stored) {
        case (.pixels(let a), .pixels(let b)): return a === b || (a.hash == b.hash && a.raster == b.raster)
        case (.drawing(let a), .drawing(let b)): return a == b
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch stored {
        case .pixels(let held):
            hasher.combine(0)
            hasher.combine(held.hash)
        case .drawing(let source):
            hasher.combine(1)
            hasher.combine(source)
        }
        hasher.combine(placement)
        hasher.combine(sampling)
        hasher.combine(edge)
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
    /// them from its `Sampler`, which inverts the placement once.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        Sampler(self).pixel(at: point)
    }
}

extension Picture.Image {
    /// The part of a picture inside a rectangle, to be drawn once and kept as an image that stands where that
    /// part stood, so that it can be shown again, moved and repeated, for the price of an image.
    ///
    /// The image holds no pixels yet: its content is a drawing, a `Part`, and the renderer that draws a picture
    /// holding the image draws the source first, when and where it chooses, and may keep the result for the next
    /// picture that holds an equal source. Making the image draws nothing. The raster will have `scale` pixels to a unit of the picture, rounded up to
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
        let part = Part(picture, in: rectangle, scale: scale, samples: samples)
        self.init(part, placement: part.placement, sampling: sampling, edge: edge)
    }

    /// This image holding its pixels: its drawing drawn by a renderer. An image that holds its pixels already is
    /// given back as it is.
    ///
    /// It fails with `.unsupported` for a rectangle with no area and for a scale that is not positive and
    /// finite, and with the renderer's own error otherwise.
    public func drawn(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Self {
        guard case .drawing(let source) = stored else { return self }
        var image = self
        image.stored = .pixels(Held(try source.raster(through: renderer)))
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
