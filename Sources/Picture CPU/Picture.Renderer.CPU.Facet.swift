import Picture

extension Picture.Renderer.CPU {
    /// What a shaded triangle shows: its model's shade made ready, the number of its ramp among the stage's,
    /// taken out of sRGB once, the matrix into eye space, and at each corner the mesh's normal and the fourth
    /// clip coordinate, by which the normals are mixed so that they follow perspective. It holds plain numbers
    /// only, so a sample point reads it without copying a ramp.
    struct Facet {
        let shade: Picture.Scene.Material.Shade.Prepared
        let ramp: Int
        let eye: Matrix<4, 4, Double>
        let normals: InlineArray<3, Vector<3, Double>>
        let divisors: InlineArray<3, Double>
    }
}

extension Picture.Renderer.CPU.Facet {
    /// The pixel at a point given by its weights on the corners in the raster's plane: the shade's pixel at
    /// the normal there, each corner's normal weighted by its weight over its own divisor, taken into eye space
    /// by `Camera.direction(_:through:)`.
    func pixel(_ weights: InlineArray<3, Double>, _ ramp: Picture.Gradient.Ramp) -> Picture.Pixel {
        let a = weights[0] / divisors[0]
        let b = weights[1] / divisors[1]
        let c = weights[2] / divisors[2]
        let total = a + b + c
        guard total != 0, total.isFinite else { return ramp.pixel(at: 0) }
        let mixed = Vector<3, Double>([
            (a * normals[0][0] + b * normals[1][0] + c * normals[2][0]) / total,
            (a * normals[0][1] + b * normals[1][1] + c * normals[2][1]) / total,
            (a * normals[0][2] + b * normals[1][2] + c * normals[2][2]) / total,
        ])
        let normal = Picture.Scene.Camera.direction(mixed, through: eye)
        return ramp.pixel(at: Float(shade.light(facing: normal)))
    }
}
