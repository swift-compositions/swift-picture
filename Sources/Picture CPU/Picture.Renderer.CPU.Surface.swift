import Picture

extension Picture.Renderer.CPU {
    /// What a glass triangle shows: its model, its glass, its corners, and whether the triangle faces the eye.
    struct Surface {
        let model: Int
        let glass: Picture.Glass
        let corners: Corners
        let front: Bool
    }
}

extension Picture.Renderer.CPU.Surface {
    init(
        model: Int,
        glass: Picture.Glass,
        normals: InlineArray<3, Vector<3, Double>>,
        divisors: InlineArray<3, Double>,
        places: InlineArray<3, Vector<3, Double>>,
        front: Bool
    ) {
        self.init(model: model, glass: glass, corners: Corners(normals: normals, divisors: divisors, places: places), front: front)
    }

    /// The normal in the model's space at a point given by its weights on the corners: `Corners.normal(_:)`.
    func normal(_ weights: InlineArray<3, Double>) -> Vector<3, Double> {
        corners.normal(weights)
    }

    /// The place in eye space at a point given by its weights on the corners: `Corners.place(_:)`.
    func place(_ weights: InlineArray<3, Double>) -> Vector<3, Double> {
        corners.place(weights)
    }
}
