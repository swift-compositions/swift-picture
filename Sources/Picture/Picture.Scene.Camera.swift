public import Matrix
public import Point
public import Projection
public import Vector

extension Picture.Scene {
    /// An eye in the world: `view` moves world space into eye space, and `projection` maps eye space
    /// onto normalised coordinates.
    public struct Camera: Sendable, Hashable {
        public var projection: Projection<Double>
        public var view: Matrix<4, 4, Double>

        public init(projection: Projection<Double>, view: Matrix<4, 4, Double> = .identity) {
            self.projection = projection
            self.view = view
        }
    }
}

extension Picture.Scene.Camera {
    /// The clip coordinates of a point of a model: projection times view times model, applied to (x, y, z, 1).
    public func clip(_ point: Point::Point<3, Double>, in model: Matrix<4, 4, Double> = .identity) -> Vector<4, Double> {
        Matrix(projection).multiplied(by: view).multiplied(by: model)
            .applied(to: Vector([point[0], point[1], point[2], 1]))
    }

    /// The normalised coordinates of a point of a model: its clip coordinates divided by the fourth.
    /// It is nil unless the fourth is positive, which is when the point is in front of the eye.
    public func normalized(_ point: Point::Point<3, Double>, in model: Matrix<4, 4, Double> = .identity) -> Point::Point<3, Double>? {
        let clip = clip(point, in: model)
        guard clip[3] > 0 else { return nil }
        return Point::Point([clip[0] / clip[3], clip[1] / clip[3], clip[2] / clip[3]])
    }

    /// A direction of a model in eye space, at unit length: the upper-left 3 × 3 of view times model
    /// applied to it. It is the zero vector when that has no length.
    public func direction(_ vector: Vector<3, Double>, in model: Matrix<4, 4, Double> = .identity) -> Vector<3, Double> {
        Self.direction(vector, through: eye(of: model))
    }

    /// View times model: what takes a model's space into eye space.
    public func eye(of model: Matrix<4, 4, Double>) -> Matrix<4, 4, Double> {
        view.multiplied(by: model)
    }

    /// A direction at unit length after the upper-left 3 × 3 of a matrix into eye space, `eye(of:)` of a
    /// model, so that `direction(_:in:)` is this with the product made once per model instead of per call.
    public static func direction(_ vector: Vector<3, Double>, through eye: Matrix<4, 4, Double>) -> Vector<3, Double> {
        let moved = eye.applied(to: Vector([vector[0], vector[1], vector[2], 0]))
        let length = (moved[0] * moved[0] + moved[1] * moved[1] + moved[2] * moved[2]).squareRoot()
        guard length > 0, length.isFinite else { return .zero }
        return Vector([moved[0] / length, moved[1] / length, moved[2] / length])
    }
}
