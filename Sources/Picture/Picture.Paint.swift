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
    public func pixel(at point: Picture.Point) -> Picture.Pixel {
        switch self {
        case .solid(let color): color.pixel
        case .linear(let linear): linear.gradient.pixel(at: Float(linear.parameter(at: point)))
        case .radial(let radial): radial.gradient.pixel(at: Float(radial.parameter(at: point)))
        case .image(let image): image.pixel(at: point)
        }
    }
}
