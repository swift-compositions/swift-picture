import Numeric

extension Picture.Scene {
    /// Air between the eye and what it sees: every surface of a scene tends toward `color` with its distance
    /// ahead of the eye, by the exponential law of fog, `density` being how much of the way one unit of
    /// distance in the scene's units takes it.
    public struct Haze: Sendable, Hashable {
        public var color: Picture.Color
        public var density: Double

        public init(_ color: Picture.Color, density: Double) {
            self.color = color
            self.density = density
        }
    }
}

extension Picture.Scene.Haze {
    /// The share of the haze's colour at a distance ahead of the eye: `1 − exp(−density × distance)`, 0 at the
    /// eye and for a distance that is not positive, never falling, and tending to 1. A density that is not
    /// positive, or what is not a number, gives 0.
    public func share(at distance: Double) -> Double {
        guard density > 0, distance > 0 else { return 0 }
        let share = -Double.expm1(-density * distance)
        return share.isFinite ? share : 0
    }

    /// A surface's pixel at a distance ahead of the eye, seen through the haze: the pixel interpolated to the
    /// haze's pixel by `share(at:)`, in linear light, colour and alpha together.
    public func pixel(_ surface: Picture.Pixel, at distance: Double) -> Picture.Pixel {
        let share = share(at: distance)
        guard share > 0 else { return surface }
        return surface.interpolated(to: color.pixel, at: Float(share))
    }
}
