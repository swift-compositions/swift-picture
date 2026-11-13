import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws a scene straight onto what is behind, the nearest surface showing` {}
}

extension `Picture CPU Tests`.`A renderer draws a scene straight onto what is behind, the nearest surface showing` {
    typealias Tests = `Picture CPU Tests`
    typealias Vertex = Point<3, Double>

    static let backdrop = Tests.pixel(0.1, 0.2, 0.3, 1)

    /// An orthographic camera over x −2…2 and y −2…2 into a viewport of 40 × 40, depth 0 at z 0 and 1 at z −10.
    static func flat(_ models: [Picture.Scene.Model]) throws -> Picture.Scene {
        let projection = try Projection<Double>.orthographic(width: 4, height: 4, near: 0, far: 10, depth: .unit)
        return Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 40, ury: 40), models: models)
    }

    /// A perspective camera, near plane at 1, a window of −1…1 there, into a viewport of 40 × 40.
    static func deep(_ models: [Picture.Scene.Model]) throws -> Picture.Scene {
        let projection = try Projection<Double>(.perspective, left: -1, right: 1, bottom: -1, top: 1, near: 1, far: 20, depth: .symmetric)
        return Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 40, ury: 40), models: models)
    }

    /// A square of side `side` around (x, y) at depth z, facing the eye.
    static func square(_ x: Double, _ y: Double, _ z: Double, side: Double = 2) throws -> Mesh<Vertex> {
        let h = side / 2
        return try Mesh(
            vertices: [Vertex([x - h, y - h, z]), Vertex([x + h, y - h, z]), Vertex([x + h, y + h, z]), Vertex([x - h, y + h, z])],
            faces: [Polygon(0, 1, 2, 3)]
        )
    }

    static func drawn(_ scene: Picture.Scene) throws -> Tests.Canvas {
        try Tests.drawn([.scene(scene)], on: Tests.canvas(40, 40, backdrop))
    }

    @Test
    func `A flat face fills with its colour over what is behind`() throws {
        let raster = try Self.drawn(Self.flat([.init(Self.square(0, 0, -5), material: .flat(Tests.translucent))]))
        #expect(Tests.at(raster, 20, 20) == Tests.translucent.pixel.composited(over: Self.backdrop))
        #expect(Tests.at(raster, 10, 10) == Tests.translucent.pixel.composited(over: Self.backdrop))
        #expect(Tests.at(raster, 9, 20) == Self.backdrop)
        #expect(Tests.at(raster, 30, 20) == Self.backdrop)
        let edge = Tests.at(raster, 29, 20)
        #expect(edge == Tests.translucent.pixel.composited(over: Self.backdrop))
        let half = try Self.drawn(Self.flat([.init(Self.square(0.05, 0, -5), material: .flat(Tests.red))]))
        #expect(Tests.close(Tests.at(half, 30, 20), Self.backdrop.interpolated(to: Tests.red.pixel, at: 0.5)))
    }

    @Test
    func `The nearer of two surfaces shows, whichever comes first, and both sides of a face are drawn`() throws {
        let near = Picture.Scene.Model(try Self.square(0, 0, -3), material: .flat(Tests.red))
        let far = Picture.Scene.Model(try Self.square(0.5, 0, -6), material: .flat(Tests.blue))
        let first = try Self.drawn(Self.flat([near, far]))
        let second = try Self.drawn(Self.flat([far, near]))
        #expect(first == second)
        #expect(Tests.at(first, 20, 20) == Tests.red.pixel)
        #expect(Tests.at(first, 32, 20) == Tests.blue.pixel)
        let reversed = Picture.Scene.Model(try Self.square(0, 0, -3).reversed, material: .flat(Tests.red))
        #expect(try Self.drawn(Self.flat([reversed, far])) == first)
    }

    @Test
    func `What lies in front of the near plane or beyond the far plane is not drawn, and a face crossing the near plane is cut there`() throws {
        let beyond = try Self.drawn(Self.flat([.init(Self.square(0, 0, -11), material: .flat(Tests.red))]))
        #expect(beyond == Tests.canvas(40, 40, Self.backdrop))
        let behind = try Self.drawn(Self.deep([.init(Self.square(0, 0, 0.5), material: .flat(Tests.red))]))
        #expect(behind == Tests.canvas(40, 40, Self.backdrop))
        let crossing = try Mesh(vertices: [Vertex([-1, -1, -2]), Vertex([1, -1, -2]), Vertex([0, 1, 0.5])], faces: [Polygon(0, 1, 2)])
        let cut = try Self.drawn(Self.deep([.init(crossing, material: .flat(Tests.translucent))]))
        let fraction = (2.0 - 1) / (2 + 0.5)
        let left = Vertex([-1 + fraction * 1, -1 + fraction * 2, -1])
        let right = Vertex([1 - fraction * 1, -1 + fraction * 2, -1])
        let trimmed = try Mesh(vertices: [Vertex([-1, -1, -2]), Vertex([1, -1, -2]), right, left], faces: [Polygon(0, 1, 2, 3)])
        let expected = try Self.drawn(Self.deep([.init(trimmed, material: .flat(Tests.translucent))]))
        #expect(Tests.close(cut, expected, within: 1e-4))
        #expect(cut != Tests.canvas(40, 40, Self.backdrop))
    }

    @Test
    func `A wireframe draws every distinct edge once, as a line of its width, and no diagonal`() throws {
        let raster = try Self.drawn(Self.flat([.init(Self.square(0, 0, -5), material: .wireframe(Tests.translucent, width: 2))]))
        let line = Tests.translucent.pixel.composited(over: Self.backdrop)
        #expect(Tests.at(raster, 20, 10) == line)
        #expect(Tests.at(raster, 20, 9) == line)
        #expect(Tests.at(raster, 20, 8) == Self.backdrop)
        #expect(Tests.at(raster, 20, 11) == Self.backdrop)
        #expect(Tests.at(raster, 20, 20) == Self.backdrop)
        #expect(Tests.at(raster, 10, 10) == line)
    }

    @Test
    func `Points draw every vertex once, as a disc of its radius`() throws {
        let raster = try Self.drawn(Self.flat([.init(Self.square(0, 0, -5), material: .points(Tests.translucent, radius: 3))]))
        let dot = Tests.translucent.pixel.composited(over: Self.backdrop)
        #expect(Tests.at(raster, 10, 10) == dot)
        #expect(Tests.at(raster, 11, 11) == dot)
        #expect(Tests.at(raster, 9, 9) == dot)
        #expect(Tests.at(raster, 14, 10) == Self.backdrop)
        #expect(Tests.at(raster, 20, 20) == Self.backdrop)
        #expect(Tests.at(raster, 29, 29) == dot)
    }

    @Test
    func `Glass shows the picture before it, read at its offset, under its tint, and only where it is not hidden`() throws {
        let gradient = Picture.Paint.linear(
            .init(from: Tests.at(0, 0), to: Tests.at(40, 0), .init([.init(offset: 0, color: Tests.red), .init(offset: 1, color: Tests.blue)]))
        )
        let background = Picture.Element.shape(.init(Tests.rectangle(-20, -20, 80, 80), fill: .init(gradient)))
        let tilt = 0.6
        let pane = try Mesh(
            vertices: [Vertex([-1, -1, -5]), Vertex([1, -1, -5 + 2 * tilt]), Vertex([1, 1, -5 + 2 * tilt]), Vertex([-1, 1, -5])],
            faces: [Polygon(0, 1, 2, 3)]
        )
        let glass = Picture.Glass(bend: 4, tint: .init(red: 1, green: 1, blue: 1, alpha: 0.25))
        let cover = Picture.Scene.Model(try Self.square(0.75, 0, -2, side: 1), material: .flat(.white))
        let scene = try Self.flat([.init(pane, material: .glass(glass)), cover])
        let raster = try Tests.drawn([background, .scene(scene)], on: Tests.canvas(40, 40))
        let length = (1 + tilt * tilt).squareRoot()
        let normal = Vector<3, Double>([-tilt / length, 0, 1 / length])
        let offset = glass.offset(for: normal)
        for (x, y): (UInt, UInt) in [(15, 15), (18, 22), (20, 18)] {
            let read = gradient.pixel(at: Tests.at(Double(x) + 0.5 + offset[0], Double(y) + 0.5 + offset[1]))
            #expect(Tests.close(Tests.at(raster, x, y), glass.pixel(over: read), within: 1e-4))
        }
        #expect(Tests.at(raster, 35, 20) == gradient.pixel(at: Tests.at(35.5, 20.5)))
        #expect(Tests.at(raster, 27, 20) == Picture.Color.white.pixel)
        let clear = try Self.flat([.init(pane, material: .glass(.init(bend: 0)))])
        let through = try Tests.drawn([background, .scene(clear)], on: Tests.canvas(40, 40))
        #expect(Tests.close(through, try Tests.drawn([background], on: Tests.canvas(40, 40))))
    }

    @Test
    func `Lit glass adds the light it reflects at its normal in eye space`() throws {
        let gradient = Picture.Paint.linear(
            .init(from: Tests.at(0, 0), to: Tests.at(40, 0), .init([.init(offset: 0, color: Tests.red), .init(offset: 1, color: Tests.blue)]))
        )
        let background = Picture.Element.shape(.init(Tests.rectangle(-20, -20, 80, 80), fill: .init(gradient)))
        let tilt = 0.6
        let pane = try Mesh(
            vertices: [Vertex([-1, -1, -5]), Vertex([1, -1, -5 + 2 * tilt]), Vertex([1, 1, -5 + 2 * tilt]), Vertex([-1, 1, -5])],
            faces: [Polygon(0, 1, 2, 3)]
        )
        let light = Picture.Glass.Light(direction: Vector([-1, 0.5, 1]), color: .white, gloss: 3, sheen: 0.4)
        let glass = Picture.Glass(bend: 4, tint: .init(red: 1, green: 1, blue: 1, alpha: 0.25), light: light)
        let raster = try Tests.drawn([background, .scene(try Self.flat([.init(pane, material: .glass(glass))]))], on: Tests.canvas(40, 40))
        let length = (1 + tilt * tilt).squareRoot()
        let normal = Vector<3, Double>([-tilt / length, 0, 1 / length])
        #expect(light.reflection(for: normal) > 0.1)
        let offset = glass.offset(for: normal)
        for (x, y): (UInt, UInt) in [(15, 15), (18, 22), (20, 18)] {
            let read = gradient.pixel(at: Tests.at(Double(x) + 0.5 + offset[0], Double(y) + 0.5 + offset[1]))
            #expect(Tests.close(Tests.at(raster, x, y), glass.pixel(over: read, facing: normal), within: 1e-4))
            #expect(Tests.at(raster, x, y) != glass.pixel(over: read))
        }
    }

    @Test
    func `A scene moves with its group and keeps to its clip`() throws {
        let scene = try Self.flat([.init(Self.square(0, 0, -5), material: .flat(Tests.red))])
        let moved = try Tests.drawn([.group(.init([.scene(scene)], transform: .translation(Vector([5, 3]))))], on: Tests.canvas(50, 50, Self.backdrop))
        #expect(Tests.at(moved, 15, 13) == Tests.red.pixel)
        #expect(Tests.at(moved, 14, 13) == Self.backdrop)
        let clipped = try Tests.drawn([.group(.init([.scene(scene)], clip: .init(Tests.rectangle(0, 0, 20.5, 40))))], on: Tests.canvas(40, 40, Self.backdrop))
        #expect(Tests.at(clipped, 19, 20) == Tests.red.pixel)
        #expect(Tests.at(clipped, 20, 20) == Self.backdrop.interpolated(to: Tests.red.pixel, at: 0.5))
        #expect(Tests.at(clipped, 21, 20) == Self.backdrop)
    }

    @Test
    func `Depth is not compared across scenes: a later scene draws over an earlier one`() throws {
        let near = try Self.flat([.init(Self.square(0, 0, -1), material: .flat(Tests.red))])
        let far = try Self.flat([.init(Self.square(0, 0, -9), material: .flat(Tests.blue))])
        let raster = try Tests.drawn([.scene(near), .scene(far)], on: Tests.canvas(40, 40, Self.backdrop))
        #expect(Tests.at(raster, 20, 20) == Tests.blue.pixel)
        let together = try Self.drawn(Self.flat([.init(Self.square(0, 0, -1), material: .flat(Tests.red)), .init(Self.square(0, 0, -9), material: .flat(Tests.blue))]))
        #expect(Tests.at(together, 20, 20) == Tests.red.pixel)
    }

    @Test
    func `Flat triangles sampled tile by tile draw what one scan of the whole raster draws: thin, tiny, clipped and flat ones, and pixels none reaches stay as they were`() throws {
        // Every number here is a whole number of sixteenths, so that moving a triangle to a tile's sample points is exact.
        let projection = try Projection<Double>.orthographic(width: 128, height: 128, near: 0, far: 16, depth: .unit)
        var corners: [[Vertex]] = [
            // Long and thin across many tiles, one of them a hair wide; a stroke as two triangles.
            [Vertex([-60, 50, -1]), Vertex([30, -20, -1]), Vertex([30.25, -20, -1])],
            [Vertex([-64, -10, -2]), Vertex([40, 60, -2]), Vertex([40, 60.0625, -2])],
            [Vertex([-50, 20, -3]), Vertex([20, 21, -3]), Vertex([20, 21.5, -3])],
            [Vertex([-50, 20, -3]), Vertex([20, 21.5, -3]), Vertex([-50, 20.5, -3])],
            // Smaller than a pixel, and around a pixel's centre.
            [Vertex([-40.5, 10.5, -2]), Vertex([-40.25, 10.5, -2]), Vertex([-40.5, 10.25, -2])],
            [Vertex([-20.75, 30.25, -2]), Vertex([-20.25, 30.25, -2]), Vertex([-20.5, 30.75, -2])],
            // Corners far off the raster, behind everything else.
            [Vertex([-4096, 40, -12]), Vertex([4096, 48, -12]), Vertex([0, -8192, -12])],
            [Vertex([-65536, 60, -11]), Vertex([65536, 59, -11]), Vertex([65536, 61, -11])],
            // Without area, and wholly off the raster.
            [Vertex([-30, -30, -1]), Vertex([0, 0, -1]), Vertex([30, 30, -1])],
            [Vertex([200, 200, -1]), Vertex([210, 200, -1]), Vertex([200, 210, -1])],
        ]
        var state: UInt64 = 7
        func sixteenths(_ low: Double, _ high: Double) -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return low + ((high - low) * 16 * Double(state >> 40) / 16_777_216).rounded(.down) / 16
        }
        (0..<40).forEach { _ in
            let start = Vertex([sixteenths(-70, 40), sixteenths(-20, 70), sixteenths(-10, -1)])
            let end = Vertex([sixteenths(-70, 40), sixteenths(-20, 70), sixteenths(-10, -1)])
            corners.append([start, end, Vertex([end[0] + sixteenths(-1, 1), end[1] + sixteenths(-1, 1), end[2]])])
        }
        let colors = corners.indices.map { index in
            Picture.Color(red: Float(index % 5) / 4, green: Float(index % 3) / 2, blue: Float(index % 7) / 6, alpha: index.isMultiple(of: 2) ? 1 : 0.5)
        }
        let models = try zip(corners, colors).map { triangle, color in
            Picture.Scene.Model(try Mesh(vertices: triangle, faces: [Polygon(0, 1, 2)]), material: .flat(color))
        }
        let scene = Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 128, ury: 128), models: models)
        let drawn = try Tests.drawn([.scene(scene)], on: Tests.canvas(96, 80, Self.backdrop))

        // The plain way: every triangle at four sample points a side over the whole raster in one scan, no
        // tiles and no pixel passed over, and each pixel the running mean of its sixteen points.
        let fine: [InlineArray<3, Point<3, Double>>] = try zip(corners, models).map { triangle, model in
            let places = try triangle.map { corner in try #require(scene.position(of: corner, in: model)) }
            return [
                Point<3, Double>([places[0].point[0] * 4, places[0].point[1] * 4, places[0].depth]),
                Point<3, Double>([places[1].point[0] * 4, places[1].point[1] * 4, places[1].depth]),
                Point<3, Double>([places[2].point[0] * 4, places[2].point[1] * 4, places[2].depth]),
            ]
        }
        let winners = Raster<Int>.fragments(of: fine, width: 384, height: 320, empty: -1) { triangle, depth in
            depth <= 1 ? Int(bitPattern: triangle) : -1
        }
        let pixels = colors.map { $0.pixel }
        var untouched = 0
        let expected = Tests.Canvas(width: 96, height: 80) { x, y in
            var mean = Self.backdrop
            var changed = false
            (0..<16).forEach { point in
                let winner = winners[x: Ordinal(UInt(Int(bitPattern: x) * 4 + point % 4)), y: Ordinal(UInt(Int(bitPattern: y) * 4 + point / 4))]
                let sample = winner >= 0 ? pixels[winner].composited(over: Self.backdrop) : Self.backdrop
                changed = changed || sample != Self.backdrop
                mean = point == 0 ? sample : mean.interpolated(to: sample, at: 1 / Float(point + 1))
            }
            if !changed { untouched += 1 }
            return changed ? mean : Self.backdrop
        }
        #expect(drawn == expected)
        #expect(Set(winners.pixels).count > 30)
        #expect(untouched > 500)
    }

    @Test
    func `A turned model under a perspective camera is drawn where the scene says each of its points lies`() throws {
        // The stage works the camera's map out once for a model; `Picture.Scene.position(of:in:)` works it out
        // for every point. One tile at the raster's corner, so that moving to its sample points changes nothing.
        let projection = try Projection<Double>(.perspective, left: -1, right: 1, bottom: -1, top: 1, near: 1, far: 20, depth: .symmetric)
        let turn = Matrix<4, 4, Double>(rows: [
            [0.8, -0.6, 0, 0.13],
            [0.6, 0.8, 0, -0.21],
            [0, 0, 1, -0.37],
            [0, 0, 0, 1],
        ])
        let meshes = [
            try Mesh(vertices: [Vertex([-9, -9, -6.3]), Vertex([9.1, -9, -7.1]), Vertex([0.3, 9.7, -5.9])], faces: [Polygon(0, 1, 2)]),
            try Mesh(vertices: [Vertex([-0.71, -0.33, -2.9]), Vertex([0.83, -0.47, -3.3]), Vertex([0.11, 0.69, -1.7])], faces: [Polygon(0, 1, 2)]),
            try Mesh(vertices: [Vertex([-1.3, 0.9, -4.1]), Vertex([1.7, 1.1, -2.3]), Vertex([1.6, 1.3, -2.2])], faces: [Polygon(0, 1, 2)]),
        ]
        let colors = [Tests.blue, Tests.red, Tests.translucent]
        let models = zip(meshes, colors).map { mesh, color in Picture.Scene.Model(mesh, transform: turn, material: .flat(color)) }
        let scene = Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 32, ury: 32), models: models)
        let drawn = try Tests.drawn([.scene(scene)], on: Tests.canvas(32, 32, Self.backdrop))

        let fine: [InlineArray<3, Point<3, Double>>] = try zip(meshes, models).map { mesh, model in
            let places = try mesh.vertices.map { corner in try #require(scene.position(of: corner, in: model)) }
            return [
                Point<3, Double>([places[0].point[0] * 4, places[0].point[1] * 4, places[0].depth]),
                Point<3, Double>([places[1].point[0] * 4, places[1].point[1] * 4, places[1].depth]),
                Point<3, Double>([places[2].point[0] * 4, places[2].point[1] * 4, places[2].depth]),
            ]
        }
        let winners = Raster<Int>.fragments(of: fine, width: 128, height: 128, empty: -1) { triangle, depth in
            depth <= 1 ? Int(bitPattern: triangle) : -1
        }
        let pixels = colors.map { $0.pixel }
        let expected = Tests.Canvas(width: 32, height: 32) { x, y in
            var mean = Self.backdrop
            (0..<16).forEach { point in
                let winner = winners[x: Ordinal(UInt(Int(bitPattern: x) * 4 + point % 4)), y: Ordinal(UInt(Int(bitPattern: y) * 4 + point / 4))]
                let sample = winner >= 0 ? pixels[winner].composited(over: Self.backdrop) : Self.backdrop
                mean = point == 0 ? sample : mean.interpolated(to: sample, at: 1 / Float(point + 1))
            }
            return mean
        }
        #expect(drawn == expected)
        #expect(Set(winners.pixels).isSuperset(of: [0, 1, 2]))
    }
}
