import Numeric
public import Vector

extension Picture.Glass {
    /// A light the glass reflects: a highlight where the surface faces halfway between the light and the
    /// eye, and a sheen at the rim where the surface turns away from the eye, brightest on the side that faces
    /// the light across the eye's view and fainter on the side opposite, as light caught inside the glass.
    public struct Light: Sendable, Hashable {
        /// Toward the light, in eye space, where the eye looks along minus z.
        public var direction: Vector<3, Double>
        public var color: Picture.Color

        /// How tight the highlight is: the power the cosine to the halfway direction is raised to.
        public var gloss: Double

        /// How strong the highlight is, 0 to 1; the rim's sheen does not depend on it.
        public var highlight: Double

        /// How much light the rim reflects where the surface is edge-on to the eye, 0 to 1.
        public var rim: Double

        /// How fast the sheen falls off away from edge-on: the power its share of `rim` is raised to.
        public var sharpness: Double

        /// How much of the sheen the side of the rim turned away from the light keeps, 0 to 1.
        public var counter: Double

        public init(
            direction: Vector<3, Double>,
            color: Picture.Color = .white,
            gloss: Double = 40,
            highlight: Double = 1,
            rim: Double = 0.5,
            sharpness: Double = 3,
            counter: Double = 0.5
        ) {
            self.direction = direction
            self.color = color
            self.gloss = gloss
            self.highlight = highlight
            self.rim = rim
            self.sharpness = sharpness
            self.counter = counter
        }
    }
}

extension Picture.Glass.Light {
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
            highlight = cosine > 0 ? Swift.min(Swift.max(self.highlight, 0), 1) * Double.exp(Swift.max(gloss, 0) * Double.log(cosine)) : 0
        }
        let edge = 1 - Swift.min(Swift.max(n.2, 0), 1)
        let power = Swift.max(sharpness, 0)
        let falloff = edge > 0 ? Double.exp(power * Double.log(edge)) : (power == 0 ? 1 : 0)
        let sheen = Swift.min(Swift.max(rim, 0), 1) * falloff * side(of: n)
        return Swift.min(Swift.max(highlight + sheen, 0), 1)
    }

    /// How much of the sheen a unit normal's side of the rim takes: for the cosine a between the normal's
    /// direction across the view (x and y) and the light's, ((1 + a) / 2)² + `counter` × ((1 − a) / 2)², so 1
    /// on the side toward the light, `counter` on the side away and a quarter of 1 + `counter` across; 1 where
    /// either has no direction across the view.
    func side(of n: (Double, Double, Double)) -> Double {
        let across = (n.0 * n.0 + n.1 * n.1).squareRoot()
        let light = (direction[0] * direction[0] + direction[1] * direction[1]).squareRoot()
        guard across > 0, light > 0, across.isFinite, light.isFinite else { return 1 }
        let a = (n.0 * direction[0] + n.1 * direction[1]) / (across * light)
        let toward = (1 + a) / 2
        let away = (1 - a) / 2
        return toward * toward + Swift.min(Swift.max(counter, 0), 1) * away * away
    }
}

extension Picture.Glass.Light {
    /// The share of the light a surface sends to the eye where its unit normal is turned away from the eye by
    /// `tilt` times its own angle, at most a right angle, about the same axis: so the rim's sheen of light bent
    /// by an index whose (n − 1) is `tilt` times the glass's sits where that light leans as far. A tilt of 1 is
    /// `reflection(for:)` itself.
    public func reflection(for normal: Vector<3, Double>, tilt: Double) -> Double {
        guard tilt != 1 else { return reflection(for: normal) }
        let length = (normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2]).squareRoot()
        let across = (normal[0] * normal[0] + normal[1] * normal[1]).squareRoot()
        guard length > 0, across > 0, length.isFinite else { return reflection(for: normal) }
        let sign: Double = normal[2] < 0 ? -1 : 1
        let angle = Swift.min(Double.atan2(across, abs(normal[2])) * Swift.max(tilt, 0), Double.pi / 2)
        let lean = Double.sin(angle) / across
        return reflection(for: Vector([normal[0] * lean, normal[1] * lean, sign * Double.cos(angle)]))
    }
}
