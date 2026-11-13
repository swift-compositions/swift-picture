import Matrix
import Vector

extension Picture.Scene.Camera {
    /// A rigid view taken apart: the rotation from the world's axes to the eye's, and the eye's place in the
    /// world, so that the view is the rotation after a move by minus the place.
    struct Pose {
        var rotation: Matrix<3, 3, Double>
        var place: Vector<3, Double>
    }
}

extension Picture.Scene.Camera.Pose {
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
}
