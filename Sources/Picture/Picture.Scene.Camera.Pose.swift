public import Angle
public import Matrix
import Numeric
public import Point
public import Vector

extension Picture.Scene.Camera {
    /// Where an eye stands and which way it is turned: the rotation from the world's axes to the eye's, and the
    /// eye's place in the world, so that the view is the rotation after a move by minus the place. A camera
    /// whose view is a rigid motion has one, `pose`; a lens and a pose make a camera.
    public struct Pose: Sendable, Hashable {
        /// The turn from the world's axes to the eye's: its rows are the eye's right, up and backward directions
        /// in the world.
        public var rotation: Matrix<3, 3, Double>

        /// Where the eye stands in the world.
        public var place: Point::Point<3, Double>

        public init(rotation: Matrix<3, 3, Double>, place: Point::Point<3, Double>) {
            self.rotation = rotation
            self.place = place
        }
    }
}

extension Picture.Scene.Camera.Pose {
    /// A view taken apart, or nil when its last row is not (0, 0, 0, 1) or its upper left 3 × 3 is not a
    /// rotation to within a millionth.
    public init?(_ view: Matrix<4, 4, Double>) {
        guard view[3, 0] == 0, view[3, 1] == 0, view[3, 2] == 0, view[3, 3] == 1 else { return nil }
        let rotation = Matrix<3, 3, Double>(rows: InlineArray { row in InlineArray { column in view[row, column] } })
        let product = rotation.multiplied(by: rotation.transposed)
        let identity = Matrix<3, 3, Double>.identity
        let drift = (0..<9).map { abs(product[$0 / 3, $0 % 3] - identity[$0 / 3, $0 % 3]) }.max() ?? 0
        guard drift <= 1e-6, rotation.determinant > 0 else { return nil }
        let moved = rotation.transposed.applied(to: Vector([view[0, 3], view[1, 3], view[2, 3]]))
        self.init(rotation: rotation, place: Point::Point([-moved[0], -moved[1], -moved[2]]))
    }

    /// An eye standing at a place of the world and turned by three angles: first `yaw` about the world's y
    /// axis, then `pitch` about the eye's own x axis, then `roll` about its own line of sight, each by the
    /// right-hand rule, so a positive yaw looks to the left, a positive pitch looks up, and a positive roll banks
    /// the eye to the left. Unturned it looks along −z with y up.
    public init(at place: Point::Point<3, Double>, yaw: Radian<Double> = .zero, pitch: Radian<Double> = .zero, roll: Radian<Double> = .zero) {
        let turn = Matrix<4, 4, Double>.rotation(aboutZ: -roll.underlying)
            .multiplied(by: .rotation(aboutX: -pitch.underlying))
            .multiplied(by: .rotation(aboutY: -yaw.underlying))
        self.init(rotation: Matrix<3, 3, Double>(rows: InlineArray { row in InlineArray { column in turn[row, column] } }), place: place)
    }

    /// An eye turned as `init(at:yaw:pitch:roll:)` turns it and standing `distance` back along its own line of
    /// sight from a target, at target + distance · (sin yaw · cos pitch, −sin pitch, cos yaw · cos pitch), so
    /// that it looks at the target: an eye on a sphere around the target, swung round it by `yaw` and over it by
    /// `pitch`.
    public init(
        around target: Point::Point<3, Double>,
        distance: Double,
        yaw: Radian<Double> = .zero,
        pitch: Radian<Double> = .zero,
        roll: Radian<Double> = .zero
    ) {
        let (across, along) = (yaw.underlying, pitch.underlying)
        let back = (x: Double.sin(across) * Double.cos(along), y: -Double.sin(along), z: Double.cos(across) * Double.cos(along))
        let place = Point::Point<3, Double>([target[0] + distance * back.x, target[1] + distance * back.y, target[2] + distance * back.z])
        self.init(at: place, yaw: yaw, pitch: pitch, roll: roll)
    }

    /// An eye at a place looking at a target, with `up` toward the top of the view: the pose of
    /// `Matrix.looking(at:from:up:)` of swift-matrix, which fails when the target is the place or `up` lies
    /// along the line of sight.
    public init(
        at place: Point::Point<3, Double>,
        looking target: Point::Point<3, Double>,
        up: Vector<3, Double> = Vector([0, 1, 0])
    ) throws(Matrix<4, 4, Double>.Error) {
        let view = try Matrix<4, 4, Double>.looking(
            at: Vector([target[0], target[1], target[2]]),
            from: Vector([place[0], place[1], place[2]]),
            up: up
        )
        self.init(rotation: Matrix<3, 3, Double>(rows: InlineArray { row in InlineArray { column in view[row, column] } }), place: place)
    }
}

extension Picture.Scene.Camera.Pose {
    /// The view this pose gives: the rotation after a move by minus the place.
    public var view: Matrix<4, 4, Double> {
        Matrix<4, 4, Double>(linear: rotation).multiplied(by: .translation(Vector([-place[0], -place[1], -place[2]])))
    }

    /// The way the eye looks, in the world, at unit length up to rounding: minus the rotation's last row.
    public var direction: Vector<3, Double> {
        Vector([-rotation[2, 0], -rotation[2, 1], -rotation[2, 2]])
    }

    /// The way the top of the view points, in the world: the rotation's middle row.
    public var up: Vector<3, Double> {
        Vector([rotation[1, 0], rotation[1, 1], rotation[1, 2]])
    }
}
