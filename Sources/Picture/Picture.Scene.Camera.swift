public import Angle
public import Matrix
import Numeric
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
    /// The product is applied to (x, y, z, 0) row by row, each summed from zero in the order of the columns, as
    /// swift-matrix's `applied(to:)` sums it.
    public static func direction(_ vector: Vector<3, Double>, through eye: Matrix<4, 4, Double>) -> Vector<3, Double> {
        func row(_ row: Int) -> Double {
            0 + eye[row, 0] * vector[0] + eye[row, 1] * vector[1] + eye[row, 2] * vector[2] + eye[row, 3] * 0
        }
        let moved = (row(0), row(1), row(2))
        let length = (moved.0 * moved.0 + moved.1 * moved.1 + moved.2 * moved.2).squareRoot()
        guard length > 0, length.isFinite else { return .zero }
        return Vector([moved.0 / length, moved.1 / length, moved.2 / length])
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

    /// A camera through a symmetric perspective lens, `init(fieldOfView:aspect:near:far:depth:view:)`, with the
    /// view of a pose.
    public init(
        fieldOfView: Radian<Double>,
        aspect: Double,
        near: Double,
        far: Double,
        depth: Projection<Double>.Depth,
        pose: Pose
    ) throws(Projection<Double>.Error) {
        try self.init(fieldOfView: fieldOfView, aspect: aspect, near: near, far: far, depth: depth, view: pose.view)
    }

    /// A camera through a centred perspective lens of a focal length, in picture units, over a viewport: its
    /// field of view is `Projection.field(focal:height:)` of the focal length and the viewport's height, and its
    /// aspect the viewport's, so a unit one unit ahead of the eye is drawn `focal` picture units long. It fails
    /// as the lens does: for a viewport with no height, a focal length that gives no field of view, and the
    /// bounds of the near and far planes.
    public init(
        focal: Double,
        viewport: Picture.Plane.Rectangle,
        near: Double,
        far: Double,
        depth: Projection<Double>.Depth,
        view: Matrix<4, 4, Double> = .identity
    ) throws(Projection<Double>.Error) {
        let width = viewport.urx.underlying - viewport.llx.underlying
        let height = viewport.ury.underlying - viewport.lly.underlying
        try self.init(
            fieldOfView: Projection<Double>.field(focal: focal, height: height),
            aspect: width / height,
            near: near,
            far: far,
            depth: depth,
            view: view
        )
    }

    /// A camera through the lens `init(focal:viewport:near:far:depth:view:)` makes, with the view of a pose.
    public init(
        focal: Double,
        viewport: Picture.Plane.Rectangle,
        near: Double,
        far: Double,
        depth: Projection<Double>.Depth,
        pose: Pose
    ) throws(Projection<Double>.Error) {
        try self.init(focal: focal, viewport: viewport, near: near, far: far, depth: depth, view: pose.view)
    }

    /// A camera through a lens with the view of a pose.
    public init(projection: Projection<Double>, pose: Pose) {
        self.init(projection: projection, view: pose.view)
    }

    /// A camera standing at a place of the world and turned by three angles: `init(projection:pose:)` with
    /// `Pose(at:yaw:pitch:roll:)`, whose view is roll, pitch and yaw undone, then the place.
    public init(
        projection: Projection<Double>,
        at place: Point::Point<3, Double>,
        yaw: Radian<Double> = .zero,
        pitch: Radian<Double> = .zero,
        roll: Radian<Double> = .zero
    ) {
        self.init(projection: projection, pose: Pose(at: place, yaw: yaw, pitch: pitch, roll: roll))
    }

    /// Where the eye stands and how it is turned, nil for a view that is not a rotation and a move to within a
    /// millionth: `Pose(view)`.
    public var pose: Pose? { Pose(view) }
}

extension Picture.Scene.Camera {
    /// A camera that shows `scale` picture units to a unit of the world at a `distance` from the eye: it stands
    /// that far along +z from the world's origin and looks along −z through a centred perspective lens whose
    /// field of view `Projection.field(focal:height:)` gives for a focal length of `scale` times the distance
    /// and the viewport's height, at the viewport's aspect. So the plane z = 0 is drawn `scale` times as large
    /// as the world, the origin at the viewport's middle, and what is nearer larger. It fails as the lens does:
    /// for a viewport with no height, a distance or scale that gives no field of view, and the bounds of the
    /// near and far planes.
    public init(
        distance: Double,
        scale: Double,
        viewport: Picture.Plane.Rectangle,
        near: Double,
        far: Double,
        depth: Projection<Double>.Depth
    ) throws(Projection<Double>.Error) {
        try self.init(
            focal: scale * distance,
            viewport: viewport,
            near: near,
            far: far,
            depth: depth,
            view: .translation(Vector([0, 0, -distance]))
        )
    }

    /// A camera that looks at a target from `distance` back along its own line of sight: `init(projection:pose:)`
    /// with `Pose(around:distance:yaw:pitch:roll:)`, which it sees at the middle of a centred lens. A positive
    /// yaw stands the eye toward +x, looking left at the target, and a positive pitch below it, looking up.
    public init(
        projection: Projection<Double>,
        around target: Point::Point<3, Double>,
        distance: Double,
        yaw: Radian<Double> = .zero,
        pitch: Radian<Double> = .zero,
        roll: Radian<Double> = .zero
    ) {
        self.init(projection: projection, pose: Pose(around: target, distance: distance, yaw: yaw, pitch: pitch, roll: roll))
    }

    /// A camera at a place looking at a target, with `up` toward the top of the view: the view is
    /// `Matrix.looking(at:from:up:)` of swift-matrix, and it fails as that does when the target is the place or
    /// `up` lies along the line of sight.
    public init(
        projection: Projection<Double>,
        at place: Point::Point<3, Double>,
        looking target: Point::Point<3, Double>,
        up: Vector<3, Double> = Vector([0, 1, 0])
    ) throws(Matrix<4, 4, Double>.Error) {
        let view = try Matrix<4, 4, Double>.looking(
            at: Vector([target[0], target[1], target[2]]),
            from: Vector([place[0], place[1], place[2]]),
            up: up
        )
        self.init(projection: projection, view: view)
    }
}

extension Picture.Scene.Camera {
    /// The point of the world that this camera shows at a point of a viewport, at a distance ahead of the eye:
    /// the way back from `sight(of:in:viewport:)`, whose position and distance for this point are the ones given,
    /// up to rounding. It is nil for a viewport with no area, a point the lens does not take back, and a view
    /// that is not a rigid motion, a rotation and a move, to within a millionth.
    public func point(under point: Picture.Plane.Point<2>, distance: Double, viewport: Picture.Plane.Rectangle) -> Point::Point<3, Double>? {
        let left = viewport.llx.underlying
        let top = viewport.lly.underlying
        let width = viewport.urx.underlying - left
        let height = viewport.ury.underlying - top
        guard width != 0, height != 0, let pose = Pose(view) else { return nil }
        let x = 2 * (point[0] - left) / width - 1
        let y = 1 - 2 * (point[1] - top) / height
        guard let window = projection.eye(Point::Point<3, Double>([x, y, projection.depth.range.lowerBound])) else { return nil }
        var eye = (x: window[0], y: window[1], z: -distance)
        if projection.kind == .perspective {
            guard window[2] < 0 else { return nil }
            let stretch = distance / -window[2]
            eye = (window[0] * stretch, window[1] * stretch, -distance)
        }
        let world = pose.rotation.transposed.applied(to: Vector([eye.x, eye.y, eye.z]))
        let found = Point::Point<3, Double>([world[0] + pose.place[0], world[1] + pose.place[1], world[2] + pose.place[2]])
        guard found[0].isFinite, found[1].isFinite, found[2].isFinite else { return nil }
        return found
    }

    /// The model transform that stands a model's origin at `point(under:distance:viewport:)`, unturned.
    public func placement(at point: Picture.Plane.Point<2>, distance: Double, viewport: Picture.Plane.Rectangle) -> Matrix<4, 4, Double>? {
        self.point(under: point, distance: distance, viewport: viewport).map { .translation(Vector([$0[0], $0[1], $0[2]])) }
    }
}

extension Picture.Scene.Camera {
    /// How far ahead of the eye a point of a model lies: minus the z of view times model applied to (x, y, z, 1),
    /// since the eye looks along −z. It is negative behind the eye.
    public func distance(of point: Point::Point<3, Double>, in model: Matrix<4, 4, Double> = .identity) -> Double {
        Self.distance(of: point, through: eye(of: model))
    }

    /// How far ahead of the eye a point lies after a matrix into eye space, `eye(of:)` of a model, so that
    /// `distance(of:in:)` is this with the product made once per model instead of per point.
    @inlinable
    public static func distance(of point: Point::Point<3, Double>, through eye: Matrix<4, 4, Double>) -> Double {
        -(eye[2, 0] * point[0] + eye[2, 1] * point[1] + eye[2, 2] * point[2] + eye[2, 3])
    }

    /// How far ahead of the eye lies what the camera draws at a normalised depth: minus the z of the eye-space
    /// point `Projection.eye(_:)` gives for it, nil where the projection has none.
    public func distance(at depth: Double) -> Double? {
        projection.eye(Point::Point<3, Double>([0, 0, depth])).map { -$0[2] }
    }

    /// A point of a model as this camera sees it in a viewport: the position `Picture.Scene` gives it, the
    /// distance `distance(of:in:)` gives it, and whether its normalised depth is at least the lower end of the
    /// projection's depth range, which is when it lies at or beyond the near plane. It is nil, as the position
    /// is, for a point in the plane of the eye or behind it.
    public func sight(
        of point: Point::Point<3, Double>,
        in model: Matrix<4, 4, Double> = .identity,
        viewport: Picture.Plane.Rectangle
    ) -> Sight? {
        guard let normalized = normalized(point, in: model) else { return nil }
        return Sight(
            position: Picture.Scene.Position(normalized, in: viewport),
            distance: distance(of: point, in: model),
            ahead: normalized[2] >= projection.depth.range.lowerBound
        )
    }
}

extension Picture.Scene.Camera {
    /// The camera a share of the way to another, as an eye that moves and turns between them at an even pace:
    /// the eye's place goes straight, and its turn goes the shorter way about one axis at an even angular
    /// rate, so the view is rigid all the way. The lens's bounds go straight when both lenses are of one kind
    /// and depth, and otherwise it is this lens below a share of 1 and the other from 1 on. A view whose upper
    /// left 3 × 3 is not a rotation, or whose last row is not (0, 0, 0, 1), is mixed entry by entry. A share of
    /// 0 gives this camera, a share of 1 the other, and equal cameras give the camera.
    public func mixed(to other: Self, at share: Double) -> Self {
        if share == 0 || self == other { return self }
        if share == 1 { return other }
        return Self(projection: Self.mixed(projection, other.projection, at: share), view: Self.mixed(view, other.view, at: share))
    }

    /// Two lenses mixed by their bounds.
    static func mixed(_ first: Projection<Double>, _ second: Projection<Double>, at share: Double) -> Projection<Double> {
        guard first != second else { return first }
        func along(_ a: Double, _ b: Double) -> Double { a == b ? a : a + (b - a) * share }
        guard first.kind == second.kind, first.depth == second.depth else { return share < 1 ? first : second }
        do throws(Projection<Double>.Error) {
            return try Projection<Double>(
                first.kind,
                left: along(first.left, second.left),
                right: along(first.right, second.right),
                bottom: along(first.bottom, second.bottom),
                top: along(first.top, second.top),
                near: along(first.near, second.near),
                far: along(first.far, second.far),
                depth: first.depth
            )
        } catch {
            return share < 1 ? first : second
        }
    }

    /// Two views mixed as rigid motions where both are, and entry by entry where either is not.
    static func mixed(_ first: Matrix<4, 4, Double>, _ second: Matrix<4, 4, Double>, at share: Double) -> Matrix<4, 4, Double> {
        guard let start = Picture.Scene.Camera.Pose(first), let end = Picture.Scene.Camera.Pose(second) else {
            return Matrix<4, 4, Double>(
                rows: InlineArray { row in
                    InlineArray { column in first[row, column] + (second[row, column] - first[row, column]) * share }
                }
            )
        }
        let turn = Quaternion(start.rotation).interpolated(to: Quaternion(end.rotation), at: share)
        let rotation = Matrix<3, 3, Double>(turn)
        let place = Vector<3, Double>([
            start.place[0] + (end.place[0] - start.place[0]) * share,
            start.place[1] + (end.place[1] - start.place[1]) * share,
            start.place[2] + (end.place[2] - start.place[2]) * share,
        ])
        let moved = rotation.applied(to: place)
        return Matrix<4, 4, Double>(rows: [
            [rotation[0, 0], rotation[0, 1], rotation[0, 2], -moved[0]],
            [rotation[1, 0], rotation[1, 1], rotation[1, 2], -moved[1]],
            [rotation[2, 0], rotation[2, 1], rotation[2, 2], -moved[2]],
            [0, 0, 0, 1],
        ])
    }
}

extension Picture.Scene.Camera {
    /// How large this camera draws a ball in a viewport: half the width of its silhouette across the line from
    /// the middle of the view, in picture units, for a ball of a radius about a centre of a model, the radius
    /// in eye space's units, so for a view and model that do not scale it is the model's.
    ///
    /// Through a perspective lens the silhouette is where the cone of sight lines that graze the ball meets the
    /// picture, not the radius over the distance: for a centre at a distance d from the eye and θ off the line
    /// of sight, and sin α = radius / d, it is f · sin α / √(cos² θ − sin² α), f being how many picture units the
    /// lens draws a unit one unit ahead, from the lens's vertical scale and the viewport's height. On the line of
    /// sight that is f · tan α, the radius of a circle; off it the silhouette is an ellipse drawn out along that
    /// line, and this is its half width across. Through an orthographic lens it is the radius times the vertical
    /// scale. It is nil for a ball that holds the eye or reaches the plane of the eye, a radius that is negative
    /// or not finite, and a viewport with no height.
    public func radius(
        of radius: Double,
        at center: Point::Point<3, Double>,
        in model: Matrix<4, 4, Double> = .identity,
        viewport: Picture.Plane.Rectangle
    ) -> Double? {
        let height = viewport.ury.underlying - viewport.lly.underlying
        guard radius >= 0, radius.isFinite, height != 0 else { return nil }
        let scale = Matrix(projection)[1, 1] * abs(height) / 2
        guard projection.kind == .perspective else { return radius * abs(scale) }
        let eye = eye(of: model).applied(to: Vector([center[0], center[1], center[2], 1]))
        let distance = (eye[0] * eye[0] + eye[1] * eye[1] + eye[2] * eye[2]).squareRoot()
        guard distance > radius, distance.isFinite else { return nil }
        let sine = radius / distance
        let cosine = -eye[2] / distance
        let room = cosine * cosine - sine * sine
        guard cosine > 0, room > 0 else { return nil }
        return abs(scale) * sine / room.squareRoot()
    }
}
