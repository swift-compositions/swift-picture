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

        /// The triangles of glass with a body that face away from the eye, where light leaves it, and their surfaces.
        var far: [InlineArray<3, Point<3, Double>>] = []
        var exits: [Surface] = []
        var bounds: Box = .empty
    }
}

extension Picture.Renderer.CPU.Stage {
    /// The scene's models as triangles in raster space under a transform from the scene's space, with
    /// points drawn as discs fine enough for a raster sampled `samples` times along each side of a pixel.
    init(_ scene: Picture.Scene, _ transform: Picture.Transform, samples: Int) {
        self.init()
        let lower = scene.camera.projection.depth.range.lowerBound
        let lens = Picture.Renderer.CPU.Lens(scene, transform)
        for (number, model) in zip(scene.models.indices, scene.models) {
            let mesh = model.mesh
            let normals: [Vector<3, Double>] = mesh.normals(per: .vertex)
            let eye = scene.camera.eye(of: model.transform)
            let corners = zip(mesh.vertices, normals).map { point, normal in
                let clip = scene.camera.clip(point, in: model.transform)
                let place = eye.applied(to: Vector([point[0], point[1], point[2], 1]))
                return Corner(
                    point: point,
                    distance: clip[2] - lower * clip[3],
                    normal: normal,
                    divisor: clip[3],
                    place: Vector([place[0], place[1], place[2]])
                )
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
                        let places: InlineArray<3, Vector<3, Double>> = [triangle.0.place, triangle.1.place, triangle.2.place]
                        let facing: InlineArray<3, Vector<3, Double>> = [
                            Picture.Scene.Camera.direction(triangle.0.normal, through: eye),
                            Picture.Scene.Camera.direction(triangle.1.normal, through: eye),
                            Picture.Scene.Camera.direction(triangle.2.normal, through: eye),
                        ]
                        let surface = Picture.Renderer.CPU.Surface(
                            model: number,
                            glass: glass,
                            normals: [triangle.0.normal, triangle.1.normal, triangle.2.normal],
                            divisors: [triangle.0.divisor, triangle.1.divisor, triangle.2.divisor],
                            places: places,
                            front: lens.faces(places, facing)
                        )
                        self.glass.append([a, b, c])
                        surfaces.append(surface)
                        if glass.refraction != nil, !surface.front {
                            far.append([a, b, c])
                            exits.append(surface)
                        }
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
            divisor: along(a.divisor, b.divisor),
            place: Vector([along(a.place[0], b.place[0]), along(a.place[1], b.place[1]), along(a.place[2], b.place[2])])
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
    /// For each tile of a box, in row order, the tile and the numbers of the triangles that can reach it, in
    /// their original order, so that a tie in depth goes to the same triangle as over the whole box. A
    /// triangle is listed for the tiles its box reaches, but for those that one of its edges clears: a long
    /// thin triangle is listed along its length, not over the whole of its box.
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
                    let left = box.left + column * side
                    let top = box.top + row * side
                    let tile = Picture.Renderer.CPU.Box(left: left - 1, top: top - 1, right: left + side + 1, bottom: top + side + 1)
                    if !clears(triangle, tile) { lists[row * columns + column].append(number) }
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

    /// Whether a box of raster space lies wholly beyond one edge of a triangle, so that the triangle has no
    /// point in it. Each corner of the box must lie beyond the edge by more than rounding can account for,
    /// here or where the triangle is sampled; a triangle without area, or one too large to measure, clears nothing.
    static func clears(_ triangle: InlineArray<3, Point<3, Double>>, _ box: Picture.Renderer.CPU.Box) -> Bool {
        let turn = (triangle[1][0] - triangle[0][0]) * (triangle[2][1] - triangle[0][1]) - (triangle[1][1] - triangle[0][1]) * (triangle[2][0] - triangle[0][0])
        guard turn > 0 || turn < 0 else { return false }
        let sign: Double = turn > 0 ? 1 : -1
        let across = (Double(box.left), Double(box.right))
        let down = (Double(box.top), Double(box.bottom))
        var edge = 0
        while edge < 3 {
            let start = triangle[edge]
            let end = triangle[(edge + 1) % 3]
            edge += 1
            let run = (x: end[0] - start[0], y: end[1] - start[1])
            /// Whether a point lies beyond the edge, on the side away from the triangle.
            func beyond(_ x: Double, _ y: Double) -> Bool {
                let slack = (abs(run.x) * (abs(y) + abs(start[1])) + abs(run.y) * (abs(x) + abs(start[0]))) * 0x1p-40
                return sign * (run.x * (y - start[1]) - run.y * (x - start[0])) < -slack
            }
            if beyond(across.0, down.0), beyond(across.1, down.0), beyond(across.0, down.1), beyond(across.1, down.1) { return true }
        }
        return false
    }

    /// Some triangles moved to a tile's sample points, `samples` to a pixel along each side.
    static func fine(
        _ triangles: [InlineArray<3, Point<3, Double>>],
        _ numbers: [Int],
        in tile: Picture.Renderer.CPU.Box,
        samples: Int
    ) -> [InlineArray<3, Point<3, Double>>] {
        let scale = Double(samples)
        return numbers.map { (number: Int) -> InlineArray<3, Point<3, Double>> in
            let triangle = triangles[number]
            func moved(_ corner: Point<3, Double>) -> Point<3, Double> {
                Point<3, Double>([(corner[0] - Double(tile.left)) * scale, (corner[1] - Double(tile.top)) * scale, corner[2]])
            }
            return [moved(triangle[0]), moved(triangle[1]), moved(triangle[2])]
        }
    }

    /// The nearest of some triangles at each sample point of a tile, `samples` × `samples` to a pixel, row by row.
    static func hits(
        _ triangles: [InlineArray<3, Point<3, Double>>],
        _ numbers: [Int],
        in tile: Picture.Renderer.CPU.Box,
        samples: Int
    ) -> [Picture.Renderer.CPU.Hit] {
        let fine = fine(triangles, numbers, in: tile, samples: samples)
        let width = Cardinal(UInt(tile.width * samples))
        let height = Cardinal(UInt(tile.height * samples))
        return Raster<Picture.Renderer.CPU.Hit>.fragments(of: fine, width: width, height: height, empty: .none) { triangle, weights, depth in
            Picture.Renderer.CPU.Hit(triangle: numbers[Int(bitPattern: triangle)], weights: weights, depth: depth)
        }.pixels
    }

    /// As `hits`, for a surface that needs no weights: which triangle is nearest at each sample point, and its depth.
    static func nearest(
        _ triangles: [InlineArray<3, Point<3, Double>>],
        _ numbers: [Int],
        in tile: Picture.Renderer.CPU.Box,
        samples: Int
    ) -> [Picture.Renderer.CPU.Hit.Nearest] {
        let fine = fine(triangles, numbers, in: tile, samples: samples)
        let width = Cardinal(UInt(tile.width * samples))
        let height = Cardinal(UInt(tile.height * samples))
        return Raster<Picture.Renderer.CPU.Hit.Nearest>.fragments(of: fine, width: width, height: height, empty: .none) { triangle, depth in
            Picture.Renderer.CPU.Hit.Nearest(triangle: numbers[Int(bitPattern: triangle)], depth: depth)
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
            let hits = Picture.Renderer.CPU.Stage.nearest(stage.opaque, numbers, in: tile, samples: samples)
            unsafe Self.visit(shared, box, tile, samples) { row, column in
                let hit = hits[row * tile.width * samples + column]
                return hit.triangle >= 0 && hit.depth <= upper
            } value: { _, _, row, column, old in
                stage.colors[hits[row * tile.width * samples + column].triangle].composited(over: old)
            } finish: { x, y, old, mean in
                Picture.Renderer.CPU.limited(old, mean, state.share(x, y))
            }
        }
        guard !stage.glass.isEmpty else { return }
        let before = raster
        let origin = box
        let glass = Picture.Renderer.CPU.Stage.tiles(stage.glass, over: area)
        let eyes = scene.models.map { scene.camera.eye(of: $0.transform) }
        let shadings = stage.surfaces.map { $0.glass.shading }
        let lens = Picture.Renderer.CPU.Lens(scene, state.transform)
        let far = Picture.Renderer.CPU.Far(stage, eyes: eyes, over: area)
        unsafe tiles(glass.count, state.workers) { shared, box, part in
            let (tile, numbers) = glass[part]
            let covers = opaque[part].triangles
            guard !numbers.isEmpty else { return }
            let hits = Picture.Renderer.CPU.Stage.hits(stage.glass, numbers, in: tile, samples: samples)
            let nearest = Picture.Renderer.CPU.Stage.nearest(stage.opaque, covers, in: tile, samples: samples)
            unsafe Self.visit(shared, box, tile, samples) { row, column in
                let position = row * tile.width * samples + column
                let hit = hits[position]
                let cover = nearest[position]
                let hidden = cover.triangle >= 0 && cover.depth <= upper && cover.depth <= hit.depth
                return hit.triangle >= 0 && hit.depth <= upper && !hidden
            } value: { x, y, row, column, old in
                let hit = hits[row * tile.width * samples + column]
                let surface = stage.surfaces[hit.triangle]
                let normal = Picture.Scene.Camera.direction(surface.normal(hit.weights), through: eyes[surface.model])
                let shading = shadings[hit.triangle]
                if let refraction = surface.glass.refraction {
                    let passage = Picture.Renderer.CPU.Passage(
                        from: surface.place(hit.weights),
                        normal: normal,
                        at: .init(
                            x: Double(x) + (Double(column % samples) + 0.5) / Double(samples),
                            y: Double(y) + (Double(row % samples) + 0.5) / Double(samples)
                        ),
                        through: refraction,
                        lens: lens,
                        far: far
                    )
                    let reads = passage.reads
                    let behind: InlineArray<3, Picture.Pixel> = [
                        Self.sample(before, origin, reads[0].x, reads[0].y, edge: .extend),
                        Self.sample(before, origin, reads[1].x, reads[1].y, edge: .extend),
                        Self.sample(before, origin, reads[2].x, reads[2].y, edge: .extend),
                    ]
                    return shading.pixel(
                        over: behind,
                        through: passage.length,
                        leaving: passage.leaving,
                        beyond: passage.beyond,
                        mirroring: passage.mirrored,
                        by: passage.share,
                        facing: normal
                    )
                }
                let offset = surface.glass.offset(for: normal)
                let across = state.transform[0, 0] * offset[0] + state.transform[0, 1] * offset[1]
                let down = state.transform[1, 0] * offset[0] + state.transform[1, 1] * offset[1]
                let point = (
                    x: Double(x) + (Double(column % samples) + 0.5) / Double(samples) + across,
                    y: Double(y) + (Double(row % samples) + 0.5) / Double(samples) + down
                )
                return shading.pixel(over: Self.sample(before, origin, point.x, point.y, edge: .extend), facing: normal)
            } finish: { x, y, old, mean in
                Picture.Renderer.CPU.limited(old, mean, state.share(x, y))
            }
        }
    }

    /// For each pixel of a tile, the mean over its `samples` × `samples` points of what `value` gives for the
    /// pixel as it is at a point that is `taken`, and of the pixel as it is at one that is not (row and column
    /// count sample points from the tile's corner), put in place by `finish`. A pixel none of whose points is
    /// taken is left alone and never read, as is one all of whose points give it back unchanged.
    static func visit(
        _ pixels: Picture.Renderer.CPU.Workers.Pixels,
        _ box: Picture.Renderer.CPU.Box,
        _ tile: Picture.Renderer.CPU.Box,
        _ samples: Int,
        taken: (_ row: Int, _ column: Int) -> Bool,
        value: (_ x: Int, _ y: Int, _ row: Int, _ column: Int, _ old: Picture.Pixel) -> Picture.Pixel,
        finish: (_ x: Int, _ y: Int, _ old: Picture.Pixel, _ mean: Picture.Pixel) -> Picture.Pixel
    ) {
        var y = tile.top
        while y < tile.bottom {
            var x = tile.left
            while x < tile.right {
                var any = false
                var point = 0
                while point < samples * samples, !any {
                    any = taken((y - tile.top) * samples + point / samples, (x - tile.left) * samples + point % samples)
                    point += 1
                }
                guard any else {
                    x += 1
                    continue
                }
                let index = box.index(x, y)
                let old = unsafe pixels[index]
                var mean = old
                var changed = false
                var count = 0
                var row = (y - tile.top) * samples
                while row < (y - tile.top + 1) * samples {
                    var column = (x - tile.left) * samples
                    while column < (x - tile.left + 1) * samples {
                        let sample = taken(row, column) ? value(x, y, row, column, old) : old
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
