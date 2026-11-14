import Numeric
public import Vector

extension Picture.Glass {
    /// A light the glass reflects: a highlight where the surface faces halfway between the light and the eye; a
    /// thin bright line along the glass's outline, as light caught in its edge; and a sheen where the surface
    /// turns away from the eye. Line and sheen are brightest on the side that faces the light across the eye's
    /// view and fainter on the side opposite.
    public struct Light: Sendable, Hashable {
        /// Toward the light, in eye space, where the eye looks along minus z.
        public var direction: Vector<3, Double>
        public var color: Picture.Color

        /// How tight the highlight is: the power the cosine to the halfway direction is raised to.
        public var gloss: Double

        /// How strong the highlight is, 0 to 1; the sheen does not depend on it.
        public var highlight: Double

        /// How bright the line along the outline is, 0 to 1.
        public var line: Double

        /// How wide the line is at full brightness, in picture units; it fades out over one and a half times
        /// that further in.
        public var width: Double

        /// How much light the surface reflects where it is edge-on to the eye, 0 to 1, apart from the line.
        public var sheen: Double

        /// How fast the sheen falls off away from edge-on: the power its share of `sheen` is raised to.
        public var sharpness: Double

        /// How much of the line and the sheen the side turned away from the light keeps, 0 to 1.
        public var counter: Double

        /// How closely line and sheen keep to the sides facing toward and away from the light: the power their
        /// share across the view is raised to, 2 by default.
        public var focus: Double

        public init(
            direction: Vector<3, Double>,
            color: Picture.Color = .white,
            gloss: Double = 40,
            highlight: Double = 1,
            line: Double = 0,
            width: Double = 2,
            sheen: Double = 0,
            sharpness: Double = 3,
            counter: Double = 0.5,
            focus: Double = 2
        ) {
            self.direction = direction
            self.color = color
            self.gloss = gloss
            self.highlight = highlight
            self.line = line
            self.width = width
            self.sheen = sheen
            self.sharpness = sharpness
            self.counter = counter
            self.focus = focus
        }
    }
}

extension Picture.Glass.Light {
    /// The share of the light, 0 to 1, a surface with a unit normal in eye space sends to the eye. Either side
    /// of a surface reflects: a normal facing away is turned to face the eye. Zero for a normal of no length.
    public func reflection(for normal: Vector<3, Double>) -> Double {
        Prepared(self).reflection(for: normal)
    }

    /// How much of the sheen a unit normal's side of the rim takes: for the cosine a between the normal's
    /// direction across the view (x and y) and the light's, ((1 + a) / 2)^f + `counter` × ((1 − a) / 2)^f for f
    /// the `focus`, so 1 on the side toward the light, `counter` on the side away and (1 + `counter`) / 2^f across;
    /// 1 where either has no direction across the view.
    func side(of n: (Double, Double, Double)) -> Double {
        Prepared(self).side(of: n)
    }

    /// The share of the light a surface sends to the eye where its unit normal is turned away from the eye by
    /// `tilt` times its own angle, at most a right angle, about the same axis: so the rim's sheen of light bent
    /// by an index whose (n − 1) is `tilt` times the glass's sits where that light leans as far. A tilt of 1 is
    /// `reflection(for:)` itself.
    public func reflection(for normal: Vector<3, Double>, tilt: Double) -> Double {
        Prepared(self).reflection(for: normal, tilt: tilt)
    }

    /// The share of the light the line along the outline sends to the eye at a point `inward` in from the outline,
    /// in picture units, where the outline's outward direction across the view, x right and y up, is `across`:
    /// `line` times the line's profile at inward / `width` times the side's share (as for the sheen). The profile is
    /// 1 from the outline to one width in, then falls to 0 at two and a half widths with no slope at either end,
    /// and is 0 outside the glass; a width that is not positive draws no line.
    public func line(at inward: Double, across: Vector<2, Double>) -> Double {
        Prepared(self).line(at: inward, across: across)
    }
}
