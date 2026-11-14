public import Angle
import Numeric

extension Picture.Effect {
    /// Everything within `radius` of `center` turned about it, by `angle` at the centre and less farther out,
    /// down to nothing at the radius: a whirlpool.
    public struct Swirl: Sendable, Hashable {
        public var center: Picture.Plane.Point<2>
        public var radius: Double
        public var angle: Radian<Double>

        public init(center: Picture.Plane.Point<2>, radius: Double, angle: Radian<Double>) {
            self.center = center
            self.radius = radius
            self.angle = angle
        }
    }
}

extension Picture.Effect.Swirl {
    /// How far a point at a distance from the centre is turned: `angle` times the square of what is left
    /// of the radius as a share of it, so the turn falls to nothing at the radius with no kink.
    public func turn(at distance: Double) -> Radian<Double> {
        guard radius > 0, distance < radius else { return .zero }
        let rest = 1 - distance / radius
        return Radian(angle.underlying * rest * rest)
    }

    /// The point of the sheet read for `point`: the point turned back about the centre by the turn at its distance.
    public func source(of point: Picture.Plane.Point<2>) -> Picture.Plane.Point<2> {
        let across = point[0] - center[0]
        let down = point[1] - center[1]
        let distance = (across * across + down * down).squareRoot()
        let turn = turn(at: distance).underlying
        guard turn != 0, turn.isFinite else { return point }
        let cosine = Double.cos(-turn)
        let sine = Double.sin(-turn)
        return Picture.Plane.Point<2>([center[0] + across * cosine - down * sine, center[1] + across * sine + down * cosine])
    }
}
