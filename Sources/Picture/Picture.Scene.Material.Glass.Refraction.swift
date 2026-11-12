public import Vector

extension Picture.Scene.Material.Glass {
    /// Glass with a body: light bends where it goes into the surface and again where it comes out of the far
    /// side, so what is seen through a round body is turned over and squeezed toward its edges; the edges
    /// mirror their surroundings more than they pass; and the colours part a little where the bend is strong.
    public struct Refraction: Sendable, Hashable {
        /// The index of refraction of the body against what is around it: 1 bends nothing, 1.5 is window glass.
        public var index: Double

        /// How far behind the place light leaves the body the picture behind stands, in the scene's units
        /// along the eye's line of sight.
        public var distance: Double

        /// How much the index differs between colours: red is bent by `index - dispersion`, green by `index`
        /// and blue by `index + dispersion`.
        public var dispersion: Double

        /// What the surface mirrors, by the share Fresnel's equations give, or nothing.
        public var surroundings: Picture.Scene.Material.Glass.Surroundings?

        public init(
            index: Double = 1.5,
            distance: Double = 1,
            dispersion: Double = 0,
            surroundings: Picture.Scene.Material.Glass.Surroundings? = nil
        ) {
            self.index = index
            self.distance = distance
            self.dispersion = dispersion
            self.surroundings = surroundings
        }
    }
}

extension Picture.Scene.Material.Glass.Refraction {
    /// The index each colour is bent by, red, green and blue in order, none below 1.
    public var indices: InlineArray<3, Double> {
        [Swift.max(index - dispersion, 1), Swift.max(index, 1), Swift.max(index + dispersion, 1)]
    }

    /// A unit direction after it crosses a surface, by Snell's law: `ratio` is the index of the side it comes
    /// from over the index of the side it goes into, and `normal` is the surface's unit normal on the side it
    /// comes from. It is nil where no light crosses: beyond the critical angle, on the way out of the denser side.
    public static func bent(_ direction: Vector<3, Double>, at normal: Vector<3, Double>, ratio: Double) -> Vector<3, Double>? {
        let cosine = -(direction[0] * normal[0] + direction[1] * normal[1] + direction[2] * normal[2])
        let inside = 1 - ratio * ratio * (1 - cosine * cosine)
        guard inside >= 0 else { return nil }
        let along = ratio * cosine - inside.squareRoot()
        return Vector([
            ratio * direction[0] + along * normal[0],
            ratio * direction[1] + along * normal[1],
            ratio * direction[2] + along * normal[2],
        ])
    }

    /// A direction after a surface with a unit normal mirrors it.
    public static func mirrored(_ direction: Vector<3, Double>, at normal: Vector<3, Double>) -> Vector<3, Double> {
        let twice = 2 * (direction[0] * normal[0] + direction[1] * normal[1] + direction[2] * normal[2])
        return Vector([direction[0] - twice * normal[0], direction[1] - twice * normal[1], direction[2] - twice * normal[2]])
    }

    /// The share of unpolarised light the surface mirrors, 0 to 1, where light meets it from outside at an angle
    /// whose cosine to the normal is `cosine`: the mean of Fresnel's two equations. It is ((n - 1) / (n + 1))²
    /// head-on and 1 at a grazing angle.
    public func reflectance(cosine: Double) -> Double {
        let n = Swift.max(index, 1)
        let c = Swift.min(Swift.max(cosine, 0), 1)
        let within = (1 - (1 - c * c) / (n * n)).squareRoot()
        let across = (c - n * within) / (c + n * within)
        let along = (n * c - within) / (n * c + within)
        guard across.isFinite, along.isFinite else { return 1 }
        return (across * across + along * along) / 2
    }
}
