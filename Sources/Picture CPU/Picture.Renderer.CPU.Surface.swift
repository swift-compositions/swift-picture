import Picture

extension Picture.Renderer.CPU {
    /// What a glass triangle shows: its model, its glass, and at each corner the mesh's normal and the
    /// fourth clip coordinate, by which the normals are mixed so that they follow perspective.
    struct Surface {
        let model: Int
        let glass: Picture.Scene.Material.Glass
        let normals: InlineArray<3, Vector<3, Double>>
        let divisors: InlineArray<3, Double>
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
}
