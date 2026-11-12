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
    /// This picture, and on top a blurred copy of it that adds its light.
    public func glow(deviation: Double, strength: Float = 1) -> Self {
        appending([
            .layer(Layer(self, effects: [.blur(Effect.Blur(deviation: deviation))], opacity: strength, operator: .lighter))
        ])
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
