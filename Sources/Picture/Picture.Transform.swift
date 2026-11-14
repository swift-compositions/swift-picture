public import Angle
public import Matrix
import Numeric
import Vector

extension Picture.Transform {
    /// A move by `x` along a row and `y` from row to row.
    public static func translation(x: Double, y: Double) -> Self {
        .translation(Vector([x, y]))
    }

    /// A scale by a factor about a point, which stays where it is: `scale(_:about:)` of swift-matrix.
    public static func scale(_ factor: Double, about point: Picture.Plane.Point<2>) -> Self {
        .scale(factor, about: Vector([point[0], point[1]]))
    }

    /// A turn by an angle about a point, which stays where it is: `rotation(_:about:)` of swift-matrix. A
    /// positive angle turns x toward y, which on a screen, with y down, is clockwise.
    public static func rotation(_ angle: Radian<Double>, about point: Picture.Plane.Point<2>) -> Self {
        .rotation(angle.underlying, about: Vector([point[0], point[1]]))
    }
}

extension Picture.Transform {
    /// The similarity that takes `anchor` to `place`, turned by an angle and scaled by a factor about it: a point
    /// p goes to place + scale · R(angle) · (p − anchor), in this order: the anchor moved to the origin, scaled,
    /// turned (a positive angle turns x toward y, clockwise on a screen), and moved to `place`. So the anchor
    /// lands on the place, lengths grow by the factor and angles turn by the angle; a factor of 1 and no angle
    /// is the translation by place − anchor.
    public init(placing anchor: Picture.Plane.Point<2>, at place: Picture.Plane.Point<2>, turn angle: Radian<Double> = .zero, scale: Double = 1) {
        let (cosine, sine) = (Double.cos(angle.underlying), Double.sin(angle.underlying))
        let linear = Matrix<2, 2, Double>(rows: [[scale * cosine, -scale * sine], [scale * sine, scale * cosine]])
        let moved = linear.applied(to: Vector([anchor[0], anchor[1]]))
        self.init(linear: linear, translation: Vector([place[0] - moved[0], place[1] - moved[1]]))
    }
}
