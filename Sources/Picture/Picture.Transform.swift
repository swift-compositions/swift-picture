public import Angle
public import Matrix
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
