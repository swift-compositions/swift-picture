import Picture

extension Picture.Renderer.CPU {
    /// A scene's camera as the glass pass needs it: from a place in eye space to the raster, and the line of
    /// sight through a place.
    struct Lens {
        let rows: InlineArray<4, InlineArray<4, Double>>
        let viewport: Projection<Double>.Viewport?
        let transform: Picture.Transform
        let map: Picture.Renderer.CPU.Affine

        /// Whether lines of sight meet at the eye; otherwise they all run along minus z.
        let converging: Bool
    }
}

extension Picture.Renderer.CPU.Lens {
    init(_ scene: Picture.Scene, _ transform: Picture.Transform) {
        let matrix = Matrix(scene.camera.projection)
        func row(_ number: Int) -> InlineArray<4, Double> {
            [matrix[number, 0], matrix[number, 1], matrix[number, 2], matrix[number, 3]]
        }
        let rows: InlineArray<4, InlineArray<4, Double>> = [row(0), row(1), row(2), row(3)]
        self.init(
            rows: rows,
            viewport: Picture.Scene.viewport(of: scene.viewport),
            transform: transform,
            map: Picture.Renderer.CPU.Affine(transform),
            converging: rows[3][0] != 0 || rows[3][1] != 0 || rows[3][2] != 0
        )
    }

    /// The unit direction light travels from the scene to the eye's place, reversed: the line of sight through
    /// a place in eye space, pointing away from the eye.
    func sight(through place: Vector<3, Double>) -> Vector<3, Double> {
        guard converging else { return Vector([0, 0, -1]) }
        let length = place.length
        guard length > 0, length.isFinite else { return Vector([0, 0, -1]) }
        return Vector([place[0] / length, place[1] / length, place[2] / length])
    }

    /// Where in the raster a place in eye space is drawn: its normalised x and y through the scene's viewport, as
    /// `Projection.Viewport.point(_:)` puts them, and the group's transform; nil for a place in the plane of the eye
    /// or behind it, and for a viewport with no area.
    @inline(__always)
    func raster(of place: Vector<3, Double>) -> (x: Double, y: Double)? {
        func clip(_ row: Int) -> Double {
            rows[row][0] * place[0] + rows[row][1] * place[1] + rows[row][2] * place[2] + rows[row][3]
        }
        let divisor = clip(3)
        guard divisor > 0, let viewport else { return nil }
        let drawn = viewport.point(Point<2, Double>(x: clip(0) / divisor, y: clip(1) / divisor))
        let moved = (map.x(drawn.x, drawn.y), map.y(drawn.x, drawn.y))
        guard moved.0.isFinite, moved.1.isFinite else { return nil }
        return moved
    }

    /// Whether a triangle with corners at places in eye space, whose unit normals there are `normals`, shows the
    /// eye the side its normals are on.
    func faces(_ places: InlineArray<3, Vector<3, Double>>, _ normals: InlineArray<3, Vector<3, Double>>) -> Bool {
        let mean = normals[0] + normals[1] + normals[2]
        var flat = (places[1] - places[0]).cross(places[2] - places[0])
        if flat.dot(mean) < 0 { flat = .zero - flat }
        if flat == .zero { flat = mean }
        let centre = (places[0] + places[1] + places[2]).map { $0 / 3 }
        let sight = sight(through: centre)
        return flat.dot(sight) < 0
    }
}
