import Numeric
import Picture

extension Picture.Renderer.CPU {
    /// A scene made ready for sampling: triangles in raster space with a depth at each corner, the colour
    /// each opaque one draws, and for each glass one the surface it shows.
    struct Stage {
        var opaque: [InlineArray<3, Point<3, Double>>] = []
        var colors: [Picture.Pixel] = []
        var glass: [InlineArray<3, Point<3, Double>>] = []
        var surfaces: [Surface] = []
        var bounds: Box = .empty
    }
}

extension Picture.Renderer.CPU.Stage {
    /// The scene's models as triangles in raster space under a transform from the scene's space, with
    /// points drawn as discs fine enough for a raster sampled `samples` times along each side of a pixel.
    init(_ scene: Picture.Scene, _ transform: Picture.Transform, samples: Int) {
        self.init()
        let lower = scene.camera.projection.depth.range.lowerBound
        for (number, model) in zip(scene.models.indices, scene.models) {
            let mesh = model.mesh
            let normals: [Vector<3, Double>] = mesh.normals(per: .vertex)
            let corners = zip(mesh.vertices, normals).map { point, normal in
                let clip = scene.camera.clip(point, in: model.transform)
                return Corner(point: point, distance: clip[2] - lower * clip[3], normal: normal, divisor: clip[3])
            }
            func project(_ corner: Corner) -> Point<3, Double>? {
                guard let position = scene.position(of: corner.point, in: model) else { return nil }
                let moved = transform.applied(to: Vector([position.point[0], position.point[1]]))
                return Point<3, Double>([moved[0], moved[1], position.depth])
            }
            switch model.material {
            case .flat(let color):
                let pixel = color.pixel
                for face in mesh.faces {
                    let polygon = Self.clipped(face.vertices.map { corners[Int(bitPattern: $0)] })
                    for triangle in Self.fan(polygon) {
                        guard let a = project(triangle.0), let b = project(triangle.1), let c = project(triangle.2) else { continue }
                        add([a, b, c], pixel)
                    }
                }

            case .glass(let glass):
                for face in mesh.faces {
                    let polygon = Self.clipped(face.vertices.map { corners[Int(bitPattern: $0)] })
                    for triangle in Self.fan(polygon) {
                        guard let a = project(triangle.0), let b = project(triangle.1), let c = project(triangle.2) else { continue }
                        self.glass.append([a, b, c])
                        surfaces.append(
                            Picture.Renderer.CPU.Surface(
                                model: number,
                                glass: glass,
                                normals: [triangle.0.normal, triangle.1.normal, triangle.2.normal],
                                divisors: [triangle.0.divisor, triangle.1.divisor, triangle.2.divisor]
                            )
                        )
                        widen([a, b, c])
                    }
                }

            case .wireframe(let color, let width):
                let pixel = color.pixel
                var seen = Set<[Int]>()
                for face in mesh.faces {
                    let indices = face.vertices.map { Int(bitPattern: $0) }
                    for (first, second) in zip(indices, indices.dropFirst() + indices.prefix(1)) {
                        let key = [Swift.min(first, second), Swift.max(first, second)]
                        guard first != second, seen.insert(key).inserted else { continue }
                        guard let (start, end) = Self.clipped(corners[first], corners[second]),
                            let a = scene.position(of: start.point, in: model),
                            let b = scene.position(of: end.point, in: model)
                        else { continue }
                        for quad in Self.line(a, b, width: width) {
                            add(quad.map { Self.moved($0, transform) }, pixel)
                        }
                    }
                }

            case .points(let color, let radius):
                let pixel = color.pixel
                let reach = radius * Picture.Renderer.CPU.stretch(transform) * Double(samples)
                let sides = reach.isFinite && reach > 0 ? Int(Swift.min(Swift.max((Double.pi * (reach / 0.2).squareRoot()).rounded(.up), 8), 256)) : 8
                for corner in corners where corner.distance >= 0 {
                    guard radius > 0, let centre = scene.position(of: corner.point, in: model) else { continue }
                    for triangle in Self.disc(centre, radius: radius, sides: sides) {
                        add(triangle.map { Self.moved($0, transform) }, pixel)
                    }
                }
            }
        }
    }

    /// An opaque triangle in raster space and its colour.
    mutating func add(_ triangle: [Point<3, Double>], _ pixel: Picture.Pixel) {
        opaque.append([triangle[0], triangle[1], triangle[2]])
        colors.append(pixel)
        widen(triangle)
    }

    /// Grows the box around everything the stage draws to hold a triangle.
    mutating func widen(_ triangle: [Point<3, Double>]) {
        let across = triangle.map { $0[0] }
        let down = triangle.map { $0[1] }
        guard across.allSatisfy(\.isFinite), down.allSatisfy(\.isFinite) else { return }
        let box = Picture.Renderer.CPU.Box(x: across.min() ?? 0, across.max() ?? 0, y: down.min() ?? 0, down.max() ?? 0)
        bounds = bounds.union(box.expanded(1, 1))
    }

    /// A position of the scene's space, with its depth, moved into raster space.
    static func moved(_ position: Picture.Scene.Position, _ transform: Picture.Transform) -> Point<3, Double> {
        let moved = transform.applied(to: Vector([position.point[0], position.point[1]]))
        return Point<3, Double>([moved[0], moved[1], position.depth])
    }

    /// The corner a fraction of the way from one corner to another, every quantity moved along a line.
    static func mix(_ a: Corner, _ b: Corner, _ fraction: Double) -> Corner {
        func along(_ x: Double, _ y: Double) -> Double { x + (y - x) * fraction }
        return Corner(
            point: Point<3, Double>([along(a.point[0], b.point[0]), along(a.point[1], b.point[1]), along(a.point[2], b.point[2])]),
            distance: along(a.distance, b.distance),
            normal: Vector([along(a.normal[0], b.normal[0]), along(a.normal[1], b.normal[1]), along(a.normal[2], b.normal[2])]),
            divisor: along(a.divisor, b.divisor)
        )
    }

    /// The part of a convex polygon in front of the near plane, cut where it crosses.
    static func clipped(_ corners: [Corner]) -> [Corner] {
        var kept: [Corner] = []
        for (a, b) in zip(corners, corners.dropFirst() + corners.prefix(1)) {
            if a.distance >= 0 { kept.append(a) }
            if (a.distance >= 0) != (b.distance >= 0) {
                kept.append(mix(a, b, a.distance / (a.distance - b.distance)))
            }
        }
        return kept
    }

    /// The part of an edge in front of the near plane, or nil when none of it is.
    static func clipped(_ a: Corner, _ b: Corner) -> (Corner, Corner)? {
        switch (a.distance >= 0, b.distance >= 0) {
        case (true, true): return (a, b)
        case (false, false): return nil
        case (true, false): return (a, mix(a, b, a.distance / (a.distance - b.distance)))
        case (false, true): return (mix(a, b, a.distance / (a.distance - b.distance)), b)
        }
    }

    /// A polygon as triangles fanning from its first corner.
    static func fan(_ polygon: [Corner]) -> [(Corner, Corner, Corner)] {
        guard let first = polygon.first else { return [] }
        return zip(polygon.dropFirst(), polygon.dropFirst(2)).map { (first, $0, $1) }
    }

    /// The two triangles of a line `width` wide from one position to another, each end at its own depth.
    static func line(_ a: Picture.Scene.Position, _ b: Picture.Scene.Position, width: Double) -> [[Picture.Scene.Position]] {
        let across = b.point[0] - a.point[0]
        let down = b.point[1] - a.point[1]
        let length = (across * across + down * down).squareRoot()
        guard length > 0, length.isFinite, width > 0 else { return [] }
        let side = (x: -down / length * width / 2, y: across / length * width / 2)
        func corner(_ position: Picture.Scene.Position, _ sign: Double) -> Picture.Scene.Position {
            Picture.Scene.Position(
                point: Picture.Plane.Point<2>([position.point[0] + sign * side.x, position.point[1] + sign * side.y]),
                depth: position.depth
            )
        }
        return [[corner(a, 1), corner(b, 1), corner(b, -1)], [corner(a, 1), corner(b, -1), corner(a, -1)]]
    }

    /// A disc of a radius around a position as triangles fanning from its centre, all at its depth.
    static func disc(_ centre: Picture.Scene.Position, radius: Double, sides: Int) -> [[Picture.Scene.Position]] {
        let rim = (0...sides).map { step in
            let angle = 2 * Double.pi * Double(step % sides) / Double(sides)
            return Picture.Scene.Position(
                point: Picture.Plane.Point<2>([centre.point[0] + radius * Double.cos(angle), centre.point[1] + radius * Double.sin(angle)]),
                depth: centre.depth
            )
        }
        return zip(rim, rim.dropFirst()).map { [centre, $0, $1] }
    }
}

extension Picture.Renderer.CPU {
    /// The sample points of a scene along each side of a pixel: a pixel takes the mean of `samples` × `samples`.
    static let samples: Int = 4

    /// The side of the square tiles a scene is sampled in, in pixels.
    static let tile: Int = 32
}

extension Picture.Renderer.CPU.Stage {
    /// For each tile of a box, in row order, the tile and the numbers of the triangles whose box reaches it,
    /// in their original order, so that a tie in depth goes to the same triangle as over the whole box.
    static func tiles(
        _ triangles: [InlineArray<3, Point<3, Double>>],
        over box: Picture.Renderer.CPU.Box
    ) -> [(tile: Picture.Renderer.CPU.Box, triangles: [Int])] {
        let side = Picture.Renderer.CPU.tile
        let columns = (box.width + side - 1) / side
        let rows = (box.height + side - 1) / side
        var lists = [[Int]](repeating: [], count: columns * rows)
        for (number, triangle) in zip(triangles.indices, triangles) {
            let across = [triangle[0][0], triangle[1][0], triangle[2][0]]
            let down = [triangle[0][1], triangle[1][1], triangle[2][1]]
            guard across.allSatisfy(\.isFinite), down.allSatisfy(\.isFinite) else { continue }
            let reach = Picture.Renderer.CPU.Box(x: across.min() ?? 0, across.max() ?? 0, y: down.min() ?? 0, down.max() ?? 0)
                .expanded(1, 1).intersection(box)
            guard reach.area > 0 else { continue }
            var row = (reach.top - box.top) / side
            while row <= (reach.bottom - 1 - box.top) / side {
                var column = (reach.left - box.left) / side
                while column <= (reach.right - 1 - box.left) / side {
                    lists[row * columns + column].append(number)
                    column += 1
                }
                row += 1
            }
        }
        return zip(lists.indices, lists).map { position, list in
            let left = box.left + (position % columns) * side
            let top = box.top + (position / columns) * side
            let tile = Picture.Renderer.CPU.Box(left: left, top: top, right: left + side, bottom: top + side).intersection(box)
            return (tile, list)
        }
    }

    /// The nearest of some triangles at each sample point of a tile, `samples` × `samples` to a pixel, row by row.
    static func hits(
        _ triangles: [InlineArray<3, Point<3, Double>>],
        _ numbers: [Int],
        in tile: Picture.Renderer.CPU.Box,
        samples: Int
    ) -> [Picture.Renderer.CPU.Hit] {
        let scale = Double(samples)
        let fine = numbers.map { (number: Int) -> InlineArray<3, Point<3, Double>> in
            let triangle = triangles[number]
            func moved(_ corner: Point<3, Double>) -> Point<3, Double> {
                Point<3, Double>([(corner[0] - Double(tile.left)) * scale, (corner[1] - Double(tile.top)) * scale, corner[2]])
            }
            return [moved(triangle[0]), moved(triangle[1]), moved(triangle[2])]
        }
        let region = Raster<Picture.Renderer.CPU.Hit>.Region(
            x: .zero,
            y: .zero,
            width: Cardinal(UInt(tile.width * samples)),
            height: Cardinal(UInt(tile.height * samples))
        )
        return Raster<Picture.Renderer.CPU.Hit>.fragments(of: fine, in: region, empty: .none) { triangle, weights, depth in
            Picture.Renderer.CPU.Hit(triangle: numbers[Int(bitPattern: triangle)], weights: weights, depth: depth)
        }.pixels
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Draws a scene straight onto what is behind. Each pixel takes the mean of `samples` × `samples` points,
    /// each showing the nearest surface there over what was behind; then glass, over the picture as it stood
    /// after every other model, read at the point plus the glass's offset.
    mutating func draw(_ scene: Picture.Scene, _ state: Picture.Renderer.CPU.State) {
        let samples = Picture.Renderer.CPU.samples
        let stage = Picture.Renderer.CPU.Stage(scene, state.transform, samples: samples)
        let area = stage.bounds.intersection(state.reach(in: box))
        guard area.area > 0 else { return }
        let upper = scene.camera.projection.depth.range.upperBound
        let opaque = Picture.Renderer.CPU.Stage.tiles(stage.opaque, over: area)
        unsafe tiles(opaque.count, state.workers) { shared, box, part in
            let (tile, numbers) = opaque[part]
            guard !numbers.isEmpty else { return }
            let hits = Picture.Renderer.CPU.Stage.hits(stage.opaque, numbers, in: tile, samples: samples)
            unsafe Self.visit(shared, box, tile, samples) { _, _, row, column, old in
                let hit = hits[row * tile.width * samples + column]
                guard hit.triangle >= 0, hit.depth <= upper else { return old }
                return stage.colors[hit.triangle].composited(over: old)
            } finish: { x, y, old, mean in
                Picture.Renderer.CPU.limited(old, mean, state.share(x, y))
            }
        }
        guard !stage.glass.isEmpty else { return }
        let before = raster
        let origin = box
        let glass = Picture.Renderer.CPU.Stage.tiles(stage.glass, over: area)
        unsafe tiles(glass.count, state.workers) { shared, box, part in
            let (tile, numbers) = glass[part]
            let covers = opaque[part].triangles
            guard !numbers.isEmpty else { return }
            let hits = Picture.Renderer.CPU.Stage.hits(stage.glass, numbers, in: tile, samples: samples)
            let nearest = Picture.Renderer.CPU.Stage.hits(stage.opaque, covers, in: tile, samples: samples)
            unsafe Self.visit(shared, box, tile, samples) { x, y, row, column, old in
                let position = row * tile.width * samples + column
                let hit = hits[position]
                let cover = nearest[position]
                let hidden = cover.triangle >= 0 && cover.depth <= upper && cover.depth <= hit.depth
                guard hit.triangle >= 0, hit.depth <= upper, !hidden else { return old }
                let surface = stage.surfaces[hit.triangle]
                let model = scene.models[surface.model]
                let normal = scene.camera.direction(surface.normal(hit.weights), in: model.transform)
                let offset = surface.glass.offset(for: normal)
                let across = state.transform[0, 0] * offset[0] + state.transform[0, 1] * offset[1]
                let down = state.transform[1, 0] * offset[0] + state.transform[1, 1] * offset[1]
                let point = (
                    x: Double(x) + (Double(column % samples) + 0.5) / Double(samples) + across,
                    y: Double(y) + (Double(row % samples) + 0.5) / Double(samples) + down
                )
                return surface.glass.pixel(over: Self.sample(before, origin, point.x, point.y, edge: .extend), facing: normal)
            } finish: { x, y, old, mean in
                Picture.Renderer.CPU.limited(old, mean, state.share(x, y))
            }
        }
    }

    /// For each pixel of a tile, the mean over its `samples` × `samples` points of what `value` gives for the
    /// pixel as it is (row and column count sample points from the tile's corner), put in place by `finish`.
    /// A pixel all of whose points give it back unchanged is left alone.
    static func visit(
        _ pixels: Picture.Renderer.CPU.Workers.Pixels,
        _ box: Picture.Renderer.CPU.Box,
        _ tile: Picture.Renderer.CPU.Box,
        _ samples: Int,
        _ value: (_ x: Int, _ y: Int, _ row: Int, _ column: Int, _ old: Picture.Pixel) -> Picture.Pixel,
        finish: (_ x: Int, _ y: Int, _ old: Picture.Pixel, _ mean: Picture.Pixel) -> Picture.Pixel
    ) {
        var y = tile.top
        while y < tile.bottom {
            var x = tile.left
            while x < tile.right {
                let index = box.index(x, y)
                let old = unsafe pixels[index]
                var mean = old
                var changed = false
                var count = 0
                var row = (y - tile.top) * samples
                while row < (y - tile.top + 1) * samples {
                    var column = (x - tile.left) * samples
                    while column < (x - tile.left + 1) * samples {
                        let sample = value(x, y, row, column, old)
                        changed = changed || sample != old
                        mean = count == 0 ? sample : mean.interpolated(to: sample, at: 1 / Float(count + 1))
                        count += 1
                        column += 1
                    }
                    row += 1
                }
                if changed { unsafe pixels[index] = finish(x, y, old, mean) }
                x += 1
            }
            y += 1
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Calls `body` for each of some tiles of the canvas on the workers, with the canvas's pixels and box;
    /// each call writes only the pixels of its own tile.
    mutating func tiles(
        _ count: Int,
        _ workers: Picture.Renderer.CPU.Workers,
        _ body: (_ pixels: Picture.Renderer.CPU.Workers.Pixels, _ box: Picture.Renderer.CPU.Box, _ part: Int) -> Void
    ) {
        let box = self.box
        pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
            workers.run(count) { part in unsafe body(shared, box, part) }
        }
    }
}
