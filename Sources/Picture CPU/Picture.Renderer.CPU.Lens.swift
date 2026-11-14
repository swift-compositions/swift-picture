import Picture

extension Picture.Renderer.CPU {
    /// A scene's camera as the glass pass needs it: from a place in eye space to the raster, and the line of
    /// sight through a place.
    struct Lens {
        let projection: Projection<Double>
        let viewport: Projection<Double>.Viewport?
        let transform: Picture.Transform
        let map: Picture.Renderer.CPU.Affine

        /// Whether lines of sight meet at the eye; otherwise they all run along minus z.
        let converging: Bool
    }
}

extension Picture.Renderer.CPU.Lens {
    init(_ scene: Picture.Scene, _ transform: Picture.Transform) {
        let projection = scene.camera.projection
        self.init(
            projection: projection,
            viewport: Picture.Scene.viewport(of: scene.viewport),
            transform: transform,
            map: Picture.Renderer.CPU.Affine(transform),
            converging: projection.kind == .perspective
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

    /// Where in the raster a place in eye space is drawn: `Projection.normalized(_:)` of its x and y, through
    /// `Projection.Viewport.point(_:)` of a viewport whose y grows downward, and the group's transform; nil for a
    /// place in the plane of the eye or behind it, where the fourth clip coordinate is not positive (minus z
    /// through a perspective lens, 1 through an orthographic one), and for a viewport with no area.
    @inline(__always)
    func raster(of place: Vector<3, Double>) -> (x: Double, y: Double)? {
        guard !converging || place[2] < 0, let viewport,
            let normalized = projection.normalized(Point(x: place[0], y: place[1], z: place[2]))
        else { return nil }
        let point = viewport.point(Point(x: normalized.x, y: normalized.y))
        let moved = (map.x(point.x, point.y), map.y(point.x, point.y))
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
