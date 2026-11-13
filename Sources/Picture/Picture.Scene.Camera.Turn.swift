import Matrix
import Numeric
import Vector

extension Picture.Scene.Camera {
    /// A rigid view taken apart: the rotation from the world's axes to the eye's, and the eye's place in the
    /// world, so that the view is the rotation after a move by minus the place.
    struct Turn {
        var rotation: Matrix<3, 3, Double>
        var place: Vector<3, Double>
    }
}

extension Picture.Scene.Camera.Turn {
    /// A view taken apart, or nil when its last row is not (0, 0, 0, 1) or its upper left 3 × 3 is not a
    /// rotation to within a millionth.
    init?(_ view: Matrix<4, 4, Double>) {
        guard view[3, 0] == 0, view[3, 1] == 0, view[3, 2] == 0, view[3, 3] == 1 else { return nil }
        let rotation = Matrix<3, 3, Double>(rows: InlineArray { row in InlineArray { column in view[row, column] } })
        let product = rotation.multiplied(by: rotation.transposed)
        let identity = Matrix<3, 3, Double>.identity
        let drift = (0..<9).map { abs(product[$0 / 3, $0 % 3] - identity[$0 / 3, $0 % 3]) }.max() ?? 0
        let determinant =
            rotation[0, 0] * (rotation[1, 1] * rotation[2, 2] - rotation[1, 2] * rotation[2, 1])
            - rotation[0, 1] * (rotation[1, 0] * rotation[2, 2] - rotation[1, 2] * rotation[2, 0])
            + rotation[0, 2] * (rotation[1, 0] * rotation[2, 1] - rotation[1, 1] * rotation[2, 0])
        guard drift <= 1e-6, determinant > 0 else { return nil }
        let moved = rotation.transposed.applied(to: Vector([view[0, 3], view[1, 3], view[2, 3]]))
        self.init(rotation: rotation, place: Vector([-moved[0], -moved[1], -moved[2]]))
    }

    /// The rotation a share of the way from none to a rotation, about the rotation's own axis, the shorter
    /// way round: the unit quaternion of the rotation, by Shepperd's method, turned through that share of its
    /// angle.
    static func part(of rotation: Matrix<3, 3, Double>, _ share: Double) -> Matrix<3, 3, Double> {
        let m = rotation
        let trace = m[0, 0] + m[1, 1] + m[2, 2]
        var q: (w: Double, x: Double, y: Double, z: Double)
        if trace > 0 {
            let s = (trace + 1).squareRoot() * 2
            q = (s / 4, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s)
        } else if m[0, 0] > m[1, 1], m[0, 0] > m[2, 2] {
            let s = (1 + m[0, 0] - m[1, 1] - m[2, 2]).squareRoot() * 2
            q = ((m[2, 1] - m[1, 2]) / s, s / 4, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s)
        } else if m[1, 1] > m[2, 2] {
            let s = (1 + m[1, 1] - m[0, 0] - m[2, 2]).squareRoot() * 2
            q = ((m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, s / 4, (m[1, 2] + m[2, 1]) / s)
        } else {
            let s = (1 + m[2, 2] - m[0, 0] - m[1, 1]).squareRoot() * 2
            q = ((m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, s / 4)
        }
        if q.w < 0 { q = (-q.w, -q.x, -q.y, -q.z) }
        let sine = (q.x * q.x + q.y * q.y + q.z * q.z).squareRoot()
        guard sine > 0, sine.isFinite else { return .identity }
        let half = Double.atan2(sine, q.w) * share
        let scale = Double.sin(half) / sine
        let (w, x, y, z) = (Double.cos(half), q.x * scale, q.y * scale, q.z * scale)
        return Matrix<3, 3, Double>(rows: [
            [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
            [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
            [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
        ])
    }
}
