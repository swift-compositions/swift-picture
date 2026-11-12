import Picture

extension Picture.Renderer.CPU {
    /// The far side of a scene's glass with a body, over a box of the raster: at each of `fine` × `fine` points
    /// to a pixel, the depth in eye space and the unit normal of the nearest surface that faces away from the
    /// eye, where light leaves the body. A depth that is not finite marks a point with no such surface.
    struct Far {
        let box: Box
        let depths: [Double]
        let normals: [Vector<3, Double>]
    }
}

extension Picture.Renderer.CPU.Far {
    /// The points along each side of a pixel.
    static let fine: Int = 2

    init(_ stage: Picture.Renderer.CPU.Stage, eyes: [Matrix<4, 4, Double>], over area: Picture.Renderer.CPU.Box) {
        let fine = Self.fine
        guard !stage.far.isEmpty, area.area > 0 else {
            self.init(box: .empty, depths: [], normals: [])
            return
        }
        let width = area.width * fine
        var depths = [Double](repeating: .infinity, count: width * area.height * fine)
        var normals = [Vector<3, Double>](repeating: .zero, count: depths.count)
        for (tile, numbers) in Picture.Renderer.CPU.Stage.tiles(stage.far, over: area) where !numbers.isEmpty {
            let hits = Picture.Renderer.CPU.Stage.hits(stage.far, numbers, in: tile, samples: fine)
            let span = tile.width * fine
            for (position, hit) in zip(hits.indices, hits) where hit.triangle >= 0 {
                let surface = stage.exits[hit.triangle]
                let place = surface.place(hit.weights)
                let normal = Picture.Scene.Camera.direction(surface.normal(hit.weights), through: eyes[surface.model])
                let index = ((tile.top - area.top) * fine + position / span) * width + (tile.left - area.left) * fine + position % span
                depths[index] = place[2]
                normals[index] = normal
            }
        }
        self.init(box: area, depths: depths, normals: normals)
    }

    /// The depth and the normal, both in eye space, of the far side at a point of the raster: the mean of
    /// the nearest points around it that have a far side, by how close each is; nil where none has.
    func read(_ x: Double, _ y: Double) -> (depth: Double, normal: Vector<3, Double>)? {
        guard box.area > 0, x.isFinite, y.isFinite else { return nil }
        let fine = Double(Self.fine)
        let width = box.width * Self.fine
        let height = box.height * Self.fine
        let across = Swift.min(Swift.max((x - Double(box.left)) * fine - 0.5, 0), Double(width - 1))
        let down = Swift.min(Swift.max((y - Double(box.top)) * fine - 0.5, 0), Double(height - 1))
        let column = Swift.min(Int(across), width - 2 >= 0 ? width - 2 : 0)
        let row = Swift.min(Int(down), height - 2 >= 0 ? height - 2 : 0)
        let u = across - Double(column)
        let v = down - Double(row)
        var depth = 0.0
        var normal = (0.0, 0.0, 0.0)
        var total = 0.0
        var corner = 0
        while corner < 4 {
            let (dx, dy) = (corner & 1, corner >> 1)
            corner += 1
            guard column + dx < width, row + dy < height else { continue }
            let index = (row + dy) * width + column + dx
            let weight = (dx == 0 ? 1 - u : u) * (dy == 0 ? 1 - v : v)
            guard weight > 0, depths[index].isFinite else { continue }
            depth += weight * depths[index]
            normal.0 += weight * normals[index][0]
            normal.1 += weight * normals[index][1]
            normal.2 += weight * normals[index][2]
            total += weight
        }
        guard total > 0 else { return nil }
        return (depth / total, Vector([normal.0 / total, normal.1 / total, normal.2 / total]))
    }
}
