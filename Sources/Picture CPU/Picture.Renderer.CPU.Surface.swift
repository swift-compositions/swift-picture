import Picture

extension Picture.Renderer.CPU {
    /// What a glass triangle shows: its model, its glass, and at each corner the mesh's normal and the
    /// fourth clip coordinate, by which the normals are mixed so that they follow perspective, each corner's
    /// place in eye space, and whether the triangle faces the eye.
    struct Surface {
        let model: Int
        let glass: Picture.Scene.Material.Glass
        let normals: InlineArray<3, Vector<3, Double>>
        let divisors: InlineArray<3, Double>
        let places: InlineArray<3, Vector<3, Double>>
        let front: Bool
    }
}

extension Picture.Renderer.CPU.Surface {
    /// The normal in the model's space at a point given by its weights on the corners in the raster's plane:
    /// each corner's weight divided by its own divisor, the three made to add up to one.
    func normal(_ weights: InlineArray<3, Double>) -> Vector<3, Double> {
        let a = weights[0] / divisors[0]
        let b = weights[1] / divisors[1]
        let c = weights[2] / divisors[2]
        let total = a + b + c
        guard total != 0, total.isFinite else { return .zero }
        return Vector([
            (a * normals[0][0] + b * normals[1][0] + c * normals[2][0]) / total,
            (a * normals[0][1] + b * normals[1][1] + c * normals[2][1]) / total,
            (a * normals[0][2] + b * normals[1][2] + c * normals[2][2]) / total,
        ])
    }

    /// The place in eye space of a point given by its weights on the corners in the raster's plane, mixed as
    /// the normal is.
    func place(_ weights: InlineArray<3, Double>) -> Vector<3, Double> {
        let a = weights[0] / divisors[0]
        let b = weights[1] / divisors[1]
        let c = weights[2] / divisors[2]
        let total = a + b + c
        guard total != 0, total.isFinite else { return .zero }
        return Vector([
            (a * places[0][0] + b * places[1][0] + c * places[2][0]) / total,
            (a * places[0][1] + b * places[1][1] + c * places[2][1]) / total,
            (a * places[0][2] + b * places[1][2] + c * places[2][2]) / total,
        ])
    }
}
