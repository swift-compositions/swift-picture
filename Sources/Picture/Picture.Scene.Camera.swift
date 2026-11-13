public import Angle
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
        Self.clip(point, through: map(of: model))
    }

    /// The normalised coordinates of a point of a model: its clip coordinates divided by the fourth.
    /// It is nil unless the fourth is positive, which is when the point is in front of the eye.
    public func normalized(_ point: Point::Point<3, Double>, in model: Matrix<4, 4, Double> = .identity) -> Point::Point<3, Double>? {
        Self.normalized(point, through: map(of: model))
    }

    /// Projection times view times model: what takes a model's space into clip space.
    public func map(of model: Matrix<4, 4, Double>) -> Matrix<4, 4, Double> {
        Matrix(projection).multiplied(by: view).multiplied(by: model)
    }

    /// The clip coordinates of a point after a matrix into clip space, `map(of:)` of a model, so that
    /// `clip(_:in:)` is this with the product made once per model instead of per point.
    @inlinable
    public static func clip(_ point: Point::Point<3, Double>, through map: Matrix<4, 4, Double>) -> Vector<4, Double> {
        map.applied(to: Vector([point[0], point[1], point[2], 1]))
    }

    /// The normalised coordinates of a point after a matrix into clip space, as `normalized(_:in:)` gives them.
    @inlinable
    public static func normalized(_ point: Point::Point<3, Double>, through map: Matrix<4, 4, Double>) -> Point::Point<3, Double>? {
        let clip = clip(point, through: map)
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

extension Picture.Scene.Camera {
    /// A camera through a symmetric perspective lens: `Projection.perspective(fieldOfView:aspect:near:far:depth:)`
    /// of swift-projection, with its failure, and a view.
    public init(
        fieldOfView: Radian<Double>,
        aspect: Double,
        near: Double,
        far: Double,
        depth: Projection<Double>.Depth,
        view: Matrix<4, 4, Double> = .identity
    ) throws(Projection<Double>.Error) {
        let projection = try Projection<Double>.perspective(fieldOfView: fieldOfView, aspect: aspect, near: near, far: far, depth: depth)
        self.init(projection: projection, view: view)
    }

    /// A camera standing at a place of the world and turned by three angles: first `yaw` about the world's y
    /// axis, then `pitch` about the eye's own x axis, then `roll` about its own line of sight. The eye looks
    /// along −z with y up, as eye space has it, before it is turned; positive angles turn by the right-hand
    /// rule, so a positive yaw looks to the left, a positive pitch looks up, and a positive roll banks the eye
    /// to the left. The view is the inverse of that placing: roll, pitch and yaw undone, then the place.
    public init(
        projection: Projection<Double>,
        at place: Point::Point<3, Double>,
        yaw: Radian<Double> = .zero,
        pitch: Radian<Double> = .zero,
        roll: Radian<Double> = .zero
    ) {
        let view = Matrix<4, 4, Double>.rotation(aboutZ: -roll.underlying)
            .multiplied(by: .rotation(aboutX: -pitch.underlying))
            .multiplied(by: .rotation(aboutY: -yaw.underlying))
            .multiplied(by: .translation(Vector([-place[0], -place[1], -place[2]])))
        self.init(projection: projection, view: view)
    }
}
