extension Picture {
    /// What a shape is filled or stroked with: a pixel for every point of the shape's space.
    public enum Paint: Sendable, Hashable {
        case solid(Color)
        case linear(Linear)
        case radial(Radial)
        case image(Picture.Image)
    }
}

extension Picture.Paint {
    /// The pixel the paint gives at a point.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        switch self {
        case .solid(let color): color.pixel
        case .linear(let linear): linear.gradient.pixel(at: Float(linear.parameter(at: point)))
        case .radial(let radial): radial.gradient.pixel(at: Float(radial.parameter(at: point)))
        case .image(let image): image.pixel(at: point)
        }
    }
}

extension Picture.Paint {
    /// A colour falling off around a centre: the colour, full at the centre, falling to nothing at the radius by
    /// `Picture.Gradient.falloff(at:core:)`, and clear beyond. A radial gradient of
    /// `Picture.Gradient.falloff(_:core:stops:)`.
    public static func falloff(
        _ color: Picture.Color,
        center: Picture.Plane.Point<2>,
        radius: Double,
        core: Double = 0.25
    ) -> Self {
        .radial(Radial(center: center, radius: radius, .falloff(color, core: core)))
    }
}
