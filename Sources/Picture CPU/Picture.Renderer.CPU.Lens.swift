import Picture

extension Picture.Renderer.CPU {
    /// A scene's camera as the glass pass needs it: from a place in eye space to the raster, and the line of
    /// sight through a place.
    struct Lens {
        let rows: InlineArray<4, InlineArray<4, Double>>
        let left: Double
        let top: Double
        let width: Double
        let height: Double
        let transform: Picture.Transform

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
            left: scene.viewport.llx.underlying,
            top: scene.viewport.lly.underlying,
            width: scene.viewport.urx.underlying - scene.viewport.llx.underlying,
            height: scene.viewport.ury.underlying - scene.viewport.lly.underlying,
            transform: transform,
            converging: rows[3][0] != 0 || rows[3][1] != 0 || rows[3][2] != 0
        )
    }

    /// The unit direction light travels from the scene to the eye's place, reversed: the line of sight through
    /// a place in eye space, pointing away from the eye.
    func sight(through place: Vector<3, Double>) -> Vector<3, Double> {
        guard converging else { return Vector([0, 0, -1]) }
        let length = (place[0] * place[0] + place[1] * place[1] + place[2] * place[2]).squareRoot()
        guard length > 0, length.isFinite else { return Vector([0, 0, -1]) }
        return Vector([place[0] / length, place[1] / length, place[2] / length])
    }

    /// Where in the raster a place in eye space is drawn, or nil for a place in the plane of the eye or behind it.
    func raster(of place: Vector<3, Double>) -> (x: Double, y: Double)? {
        func clip(_ row: Int) -> Double {
            rows[row][0] * place[0] + rows[row][1] * place[1] + rows[row][2] * place[2] + rows[row][3]
        }
        let divisor = clip(3)
        guard divisor > 0 else { return nil }
        let across = left + (clip(0) / divisor + 1) / 2 * width
        let down = top + (1 - clip(1) / divisor) / 2 * height
        let moved = transform.applied(to: Vector([across, down]))
        guard moved[0].isFinite, moved[1].isFinite else { return nil }
        return (moved[0], moved[1])
    }

    /// Whether a triangle with corners at places in eye space, whose unit normals there are `normals`, shows the
    /// eye the side its normals are on.
    func faces(_ places: InlineArray<3, Vector<3, Double>>, _ normals: InlineArray<3, Vector<3, Double>>) -> Bool {
        let u = (places[1][0] - places[0][0], places[1][1] - places[0][1], places[1][2] - places[0][2])
        let v = (places[2][0] - places[0][0], places[2][1] - places[0][1], places[2][2] - places[0][2])
        var flat = (u.1 * v.2 - u.2 * v.1, u.2 * v.0 - u.0 * v.2, u.0 * v.1 - u.1 * v.0)
        let mean = (normals[0][0] + normals[1][0] + normals[2][0], normals[0][1] + normals[1][1] + normals[2][1], normals[0][2] + normals[1][2] + normals[2][2])
        if flat.0 * mean.0 + flat.1 * mean.1 + flat.2 * mean.2 < 0 { flat = (-flat.0, -flat.1, -flat.2) }
        if flat.0 == 0, flat.1 == 0, flat.2 == 0 { flat = mean }
        let centre = Vector<3, Double>([
            (places[0][0] + places[1][0] + places[2][0]) / 3,
            (places[0][1] + places[1][1] + places[2][1]) / 3,
            (places[0][2] + places[1][2] + places[2][2]) / 3,
        ])
        let sight = sight(through: centre)
        return flat.0 * sight[0] + flat.1 * sight[1] + flat.2 * sight[2] < 0
    }
}
