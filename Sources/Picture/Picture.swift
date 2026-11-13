public import Geometry
public import Matrix
public import W3C_CSS_Compositing

/// A picture as a value: a list of elements, drawn in order, the first at the back.
public struct Picture: Sendable, Hashable {
    public var elements: [Element]

    public init(_ elements: [Element] = []) {
        self.elements = elements
    }
}

extension Picture {
    /// The geometry of picture space: `Double` coordinates in `Picture.Space`.
    public typealias Plane = Geometry<Double, Space>

    /// An affine map of picture space, applied to (x, y, 1).
    public typealias Transform = Matrix<2, 3, Double>

    /// The pixel a picture is drawn in: premultiplied, linear light, single precision.
    public typealias Pixel = Compositing.Premultiplied<Float>
}

extension Picture {
    /// The picture that draws nothing.
    public static var empty: Self { Self() }

    /// This picture's elements followed by the other's, so the other is drawn on top.
    public func appending(_ other: Self) -> Self {
        Self(elements + other.elements)
    }
}

extension Picture {
    /// This picture, and on top a blurred copy of it that adds its light, kept out of what a mask covers.
    ///
    /// Without a mask the light is one layer of this picture under the blur, with `strength` as opacity and
    /// `lighter` as operator. With one, that layer holds the blurred picture and then the mask in a layer under
    /// `destinationOut`, so each pixel of the light keeps one minus the mask's alpha there before it is added:
    /// where the mask is opaque the picture is left as it is drawn, as a ring's glow that does not fill its
    /// middle, and where the mask fades the light comes back. The mask is in this picture's space.
    /// A strength of 0 adds no light, and gives this picture itself.
    public func glow(deviation: Double, strength: Float = 1, sparing mask: Self = .empty) -> Self {
        guard strength != 0 else { return self }
        let blurred = Layer(self, effects: [.blur(Effect.Blur(deviation: deviation))], opacity: strength, operator: .lighter)
        guard !mask.elements.isEmpty else { return appending([.layer(blurred)]) }
        let light: Self = [
            .layer(Layer(self, effects: [.blur(Effect.Blur(deviation: deviation))])),
            .layer(Layer(mask, operator: .destinationOut)),
        ]
        return appending([.layer(Layer(light, opacity: strength, operator: .lighter))])
    }

    /// This picture, and on top, inside a clip, this picture again changed by effects and put in
    /// place of what was there: a pane that blurs or bends what is behind it.
    public func backdrop(_ effects: [Effect], clip: Clip) -> Self {
        appending([
            .group(Group([.layer(Layer(self, effects: effects, operator: .copy))], clip: clip))
        ])
    }
}

extension Picture {
    /// This picture with the light of its bright parts spread over it, as a lens and the eye spread a bright
    /// light: the picture kept as an image of the rectangle, and on top, under `lighter` with `strength` as
    /// opacity, the same image under `threshold` and blurred, kept again at `resolution` times its scale.
    ///
    /// The light is the mean of `octaves` blurs whose deviations halve from `deviation`, so a bright point
    /// spreads with a sharp core and a long, faint tail rather than as one Gaussian, and since each blur keeps
    /// the light it is given, the light added is `strength` times what the threshold keeps. The picture is
    /// drawn once, into the first image, and the blurs are drawn at the second image's resolution, where they
    /// cost a fourth of the pixels at the default half. Nothing above the threshold, no octaves or no strength
    /// give the kept picture alone. Light that would spread past the rectangle is not drawn.
    public func bloom(
        in rectangle: Plane.Rectangle,
        threshold: Effect.Threshold = Effect.Threshold(),
        deviation: Double = 24,
        octaves: Cardinal = 3,
        strength: Float = 1,
        scale: Double = 1,
        resolution: Double = 0.5
    ) -> Self {
        let count = Int(clamping: octaves)
        let passes = (0..<count).map { octave in
            [Effect.threshold(threshold), .blur(Effect.Blur(deviation: deviation / Double(1 << Swift.min(octave, 62))))]
        }
        return lit(by: passes, in: rectangle, strength: strength, scale: scale, resolution: resolution)
    }

    /// This picture with the light of its bright parts streaming away from a point, as light through haze: the
    /// picture kept as an image of the rectangle, and on top, under `lighter` with `strength` as opacity, the
    /// mean of `streaks` passes of the same image under `threshold`, the k-th of n a `zoom` toward the point of
    /// amount `length × k / n`, kept again at `resolution` times its scale. A bright part at a distance r from
    /// the point leaves a streak reaching out to r / (1 − length), brightest near the part and fading as it goes
    /// in n steps. The picture is drawn once; nothing above the threshold, no streaks, no length or no
    /// strength give the kept picture alone.
    public func rays(
        from center: Plane.Point<2>,
        in rectangle: Plane.Rectangle,
        threshold: Effect.Threshold = Effect.Threshold(),
        length: Double = 0.5,
        streaks: Cardinal = 4,
        strength: Float = 1,
        scale: Double = 1,
        resolution: Double = 0.5
    ) -> Self {
        let count = length == 0 ? 0 : Int(clamping: streaks)
        let passes = (0..<count).map { streak in
            [Effect.threshold(threshold), .zoom(Effect.Zoom(center: center, amount: length * Double(streak + 1) / Double(count)))]
        }
        return lit(by: passes, in: rectangle, strength: strength, scale: scale, resolution: resolution)
    }

    /// The picture kept in a rectangle, and on top the mean of that image under each list of effects, kept
    /// again at a resolution and added with a strength.
    func lit(by passes: [[Effect]], in rectangle: Plane.Rectangle, strength: Float, scale: Double, resolution: Double) -> Self {
        let kept = Element.image(self, in: rectangle, scale: scale)
        guard !passes.isEmpty, strength != 0 else { return [kept] }
        let share = 1 / Float(passes.count)
        let light = Self(passes.map { .layer(Layer([kept], effects: $0, opacity: share, operator: .lighter)) })
        let spread = Element.image(light, in: rectangle, scale: scale * resolution)
        return [kept, .layer(Layer([spread], opacity: strength, operator: .lighter))]
    }

    /// The path around a rectangle.
    static func area(_ rectangle: Plane.Rectangle) -> Plane.Path {
        let (left, top) = (rectangle.llx.underlying, rectangle.lly.underlying)
        let (right, bottom) = (rectangle.urx.underlying, rectangle.ury.underlying)
        let corners: [Plane.Point<2>] = [.init([left, top]), .init([right, top]), .init([right, bottom]), .init([left, bottom])]
        let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
            Plane.Path.Segment.line(.init(start: start, end: end))
        }
        return Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
    }
}

extension Picture {
    /// The mean of pictures, each drawn on a sheet of its own: one layer that holds, for each picture, a
    /// layer with one part in their number as opacity and `lighter` as operator, so the sheets add up to
    /// their mean, colour and alpha alike. No pictures give the empty picture, and one picture gives itself.
    public static func mean(of pictures: [Self]) -> Self {
        guard pictures.count > 1 else { return pictures.first ?? .empty }
        let share = 1 / Float(pictures.count)
        return [.layer(Layer(Self(pictures.map { .layer(Layer($0, opacity: share, operator: .lighter)) })))]
    }

    /// A picture that changes while a shutter is open, as the shutter records it: the mean of the picture at
    /// the midpoints of `samples` equal parts of the exposure, which runs from fraction 0 to fraction 1.
    /// What moves is smeared along its way, and what stands still is drawn as it is. No samples give the
    /// empty picture, and one gives the picture at fraction one half.
    public static func exposure<Failure: Swift.Error>(
        samples: Cardinal,
        _ picture: (_ fraction: Double) throws(Failure) -> Self
    ) throws(Failure) -> Self {
        let count = Int(clamping: samples)
        var pictures: [Self] = []
        pictures.reserveCapacity(count)
        for sample in 0..<count {
            pictures.append(try picture((Double(sample) + 0.5) / Double(count)))
        }
        return mean(of: pictures)
    }
}

extension Picture: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
