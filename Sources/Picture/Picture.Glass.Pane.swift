import Numeric
public import Vector

extension Picture.Glass {
    /// A flat piece of a glass lying over the picture: a slab `thickness` thick over a region of the plane,
    /// whose top is level in the middle and falls to the region's boundary across a rim `rim` wide, rounded
    /// like the edge of a pebble. The picture behind is read through it as through the glass's body: bent where
    /// light goes into the rounded top and again where it leaves the flat bottom, so the middle shows the
    /// picture as it is and the rim lenses it, frosted, adapted, tinted and lit as the glass says.
    ///
    /// Every quantity is a plain value, so a pane can change from frame to frame: its region (two regions that
    /// come close join with a rounded neck under `Picture.Plane.Region.union(_:radius:)`), thickness, rim, the
    /// glass's light and all; the picture changes continuously with each of them.
    public struct Pane: Sendable, Hashable {
        /// Where the pane lies, by its signed distance.
        public var region: Picture.Plane.Region

        /// What the pane is made of.
        public var glass: Picture.Glass

        /// How high the slab's level middle stands over its flat bottom, in picture units.
        public var thickness: Double

        /// How far in from the boundary the top falls to it, in picture units.
        public var rim: Double

        /// The power p of the rim's profile, a superellipse's quarter. From 3 on, the default, the top meets its
        /// level middle with no bend, so lines seen through the rim bend smoothly into the middle; 2 is a quarter
        /// circle, which meets it with a bend that shows as a kink in such lines; more is flatter on top and
        /// steeper at the boundary.
        public var profile: Double

        public init(
            _ region: Picture.Plane.Region,
            glass: Picture.Glass,
            thickness: Double = 24,
            rim: Double = 24,
            profile: Double = 3
        ) {
            self.region = region
            self.glass = glass
            self.thickness = thickness
            self.rim = rim
            self.profile = profile
        }
    }
}

extension Picture.Glass.Pane {
    /// How high the top stands at a distance `inward` in from the boundary: `thickness` times
    /// (1 − (1 − u)^p)^(1/p) for u = inward / rim and p the `profile`, a superellipse's quarter, which meets the
    /// boundary upright and the level middle with no slope; `thickness` from the rim on, and 0 on the boundary
    /// and outside. A profile below 1 counts as 1.
    public func height(at inward: Double) -> Double {
        guard inward > 0, thickness > 0 else { return 0 }
        guard rim > 0, inward < rim else { return thickness }
        let p = Swift.max(profile, 1)
        let v = 1 - inward / rim
        if p == 2 { return thickness * (1 - v * v).squareRoot() }
        let rest = 1 - Double.exp(p * Double.log(v))
        return thickness * Double.exp(Double.log(rest) / p)
    }

    /// How fast the top rises going in, at a distance `inward` in from the boundary: the derivative of
    /// `height(at:)`, `thickness / rim` times (1 − u)^(p − 1) · (1 − (1 − u)^p)^(1/p − 1) in the form above; 0
    /// from the rim on, where the top is level, and infinite on the boundary.
    public func slope(at inward: Double) -> Double {
        guard thickness > 0 else { return 0 }
        guard rim > 0, inward < rim else { return 0 }
        guard inward > 0 else { return .infinity }
        let p = Swift.max(profile, 1)
        let v = 1 - inward / rim
        if p == 2 { return thickness / rim * v / (1 - v * v).squareRoot() }
        let power = Double.exp(p * Double.log(v))
        return thickness / rim * power / v * Double.exp((1 / p - 1) * Double.log(1 - power))
    }

    /// The top's unit normal in eye space at a point of the picture, where x runs right, y up and z toward the
    /// eye, as `Picture.Glass.offset(for:)` and `Picture.Glass.Light` take it: for the region's sample there,
    /// distance d and gradient g, it is (s·gx, −s·gy, 1) at unit length for the slope s at −d, so it leans out
    /// across the rim and faces the eye where the top is level. Upright, (gx, −gy, 0), on the boundary.
    public func normal(at point: Picture.Plane.Point<2>) -> Vector<3, Double> {
        normal(for: region.sample(at: point))
    }

    /// The normal for a sample of the region, as `normal(at:)` gives it.
    public func normal(for sample: Picture.Plane.Region.Sample) -> Vector<3, Double> {
        let s = slope(at: -sample.distance)
        let g = (sample.gradient[0], sample.gradient[1])
        guard s.isFinite else {
            let length = (g.0 * g.0 + g.1 * g.1).squareRoot()
            guard length > 0 else { return Vector([0, 0, 1]) }
            return Vector([g.0 / length, -g.1 / length, 0])
        }
        let n = (s * g.0, -s * g.1, 1.0)
        let length = (n.0 * n.0 + n.1 * n.1 + n.2 * n.2).squareRoot()
        return Vector([n.0 / length, n.1 / length, n.2 / length])
    }

    /// What light does at a point of the pane: `Passage(through:at:)` for this pane.
    public func passage(at point: Picture.Plane.Point<2>) -> Passage {
        Passage(through: self, for: region.sample(at: point))
    }
}
