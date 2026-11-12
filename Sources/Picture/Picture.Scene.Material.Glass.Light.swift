import Numeric
public import Vector

extension Picture.Scene.Material.Glass {
    /// A light the glass reflects: a highlight where the surface faces halfway between the light and the
    /// eye, and a sheen at the rim where the surface turns away from the eye.
    public struct Light: Sendable, Hashable {
        /// Toward the light, in eye space, where the eye looks along minus z.
        public var direction: Vector<3, Double>
        public var color: Picture.Color

        /// How tight the highlight is: the power the cosine to the halfway direction is raised to.
        public var gloss: Double

        /// How much light the rim reflects where the surface is edge-on to the eye, 0 to 1.
        public var rim: Double

        public init(direction: Vector<3, Double>, color: Picture.Color = .white, gloss: Double = 40, rim: Double = 0.5) {
            self.direction = direction
            self.color = color
            self.gloss = gloss
            self.rim = rim
        }
    }
}

extension Picture.Scene.Material.Glass.Light {
    /// The share of the light, 0 to 1, a surface with a unit normal in eye space sends to the eye. Either side
    /// of a surface reflects: a normal facing away is turned to face the eye. Zero for a normal of no length.
    public func reflection(for normal: Vector<3, Double>) -> Double {
        let length = (normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2]).squareRoot()
        guard length > 0, length.isFinite else { return 0 }
        let sign: Double = normal[2] < 0 ? -1 : 1
        let n = (sign * normal[0] / length, sign * normal[1] / length, sign * normal[2] / length)
        var half = (direction[0], direction[1], direction[2])
        let reach = (half.0 * half.0 + half.1 * half.1 + half.2 * half.2).squareRoot()
        var highlight = 0.0
        if reach > 0, reach.isFinite {
            half = (half.0 / reach, half.1 / reach, half.2 / reach + 1)
            let size = (half.0 * half.0 + half.1 * half.1 + half.2 * half.2).squareRoot()
            let cosine = size > 0 ? (n.0 * half.0 + n.1 * half.1 + n.2 * half.2) / size : 0
            highlight = cosine > 0 ? Double.exp(Swift.max(gloss, 0) * Double.log(cosine)) : 0
        }
        let edge = 1 - Swift.min(Swift.max(n.2, 0), 1)
        let sheen = Swift.min(Swift.max(rim, 0), 1) * edge * edge * edge
        return Swift.min(Swift.max(highlight + sheen, 0), 1)
    }
}
