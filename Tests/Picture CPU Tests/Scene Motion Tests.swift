import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A scene is blurred by its camera's travel, hazed by distance, and a kaleidoscope keeps its edges` {}
}

extension `Picture CPU Tests`.`A scene is blurred by its camera's travel, hazed by distance, and a kaleidoscope keeps its edges` {
    typealias Tests = `Picture CPU Tests`
    typealias Vertex = Point<3, Double>

    static let backdrop = Tests.pixel(0, 0, 0, 1)

    /// A box from one corner to the other.
    static func box(_ low: Vertex, _ high: Vertex) throws -> Mesh<Vertex> {
        let (a, b) = (low, high)
        return try Mesh(
            vertices: [
                Vertex([a[0], a[1], a[2]]), Vertex([b[0], a[1], a[2]]), Vertex([b[0], b[1], a[2]]), Vertex([a[0], b[1], a[2]]),
                Vertex([a[0], a[1], b[2]]), Vertex([b[0], a[1], b[2]]), Vertex([b[0], b[1], b[2]]), Vertex([a[0], b[1], b[2]]),
            ],
            faces: [Polygon(0, 1, 2, 3), Polygon(4, 5, 6, 7), Polygon(0, 1, 5, 4), Polygon(2, 3, 7, 6), Polygon(1, 2, 6, 5), Polygon(0, 3, 7, 4)]
        )
    }

    /// A row of boxes receding along −z on both sides of the way, in colours of several brightnesses.
    static func street(_ camera: Picture.Scene.Camera, width: Double, height: Double, haze: Picture.Scene.Haze? = nil) throws -> Picture.Scene {
        let colours: [Picture.Color] = [
            .init(red: 0.9, green: 0.3, blue: 0.2), .init(red: 0.2, green: 0.7, blue: 0.9), .init(red: 0.95, green: 0.9, blue: 0.6),
        ]
        let models = try (0..<12).flatMap { step -> [Picture.Scene.Model] in
            let z = -4 - 3.5 * Double(step)
            let colour = colours[step % 3]
            return [
                Picture.Scene.Model(try box(Vertex([-3, -1, z - 1]), Vertex([-1.6, 1.2 + 0.3 * Double(step % 4), z])), material: .flat(colour)),
                Picture.Scene.Model(try box(Vertex([1.6, -1, z - 2]), Vertex([3, 2 - 0.25 * Double(step % 3), z - 0.5])), material: .flat(colour)),
            ]
        }
        return Picture.Scene(camera: camera, viewport: .init(llx: 0, lly: 0, urx: .init(width), ury: .init(height)), models: models, haze: haze)
    }

    static func camera(at place: Vertex, yaw: Double = 0) throws -> Picture.Scene.Camera {
        let projection = try Projection<Double>.perspective(fieldOfView: Radian(1.0), aspect: 16 / 9, near: 0.3, far: 80, depth: .unit)
        return Picture.Scene.Camera(projection: projection, at: place, yaw: Radian(yaw))
    }

    static func drawn(_ picture: Picture, threads: Cardinal = 4) throws -> Tests.Canvas {
        var raster = Tests.canvas(160, 90, backdrop)
        try Picture.Renderer.cpu(threads: threads).render(picture, into: &raster)
        return raster
    }

    static func brightest(_ raster: Tests.Canvas) -> Float {
        raster.pixels.map { Swift.max($0.color.red, $0.color.green, $0.color.blue) }.max() ?? 0
    }

    @Test
    func `A still camera's blur draws the unblurred scene, bit for bit`() throws {
        let scene = try Self.street(Self.camera(at: Vertex([0, 0, 0])), width: 160, height: 90)
        let plain = try Self.drawn([.scene(scene)])
        for exposure: Picture.Scene.Exposure in [.samples(5), .bands(4)] {
            #expect(try Self.drawn(scene.exposure(since: scene.camera, exposure)) == plain)
        }
    }

    @Test
    func `Blur never brightens beyond the unblurred frame's brightest, travelling forward or turning`() throws {
        let now = try Self.camera(at: Vertex([0, 0, 0]), yaw: 0.05)
        let scene = try Self.street(now, width: 160, height: 90)
        let plain = try Self.drawn([.scene(scene)])
        let limit = Self.brightest(plain) + 1e-5
        for earlier in [try Self.camera(at: Vertex([0, 0, 1.5]), yaw: 0.05), try Self.camera(at: Vertex([0, 0, 0]), yaw: -0.1)] {
            for exposure: Picture.Scene.Exposure in [.samples(6), .bands(4)] {
                let blurred = try Self.drawn(scene.exposure(since: earlier, exposure))
                #expect(blurred != plain)
                #expect(Self.brightest(blurred) <= limit, "\(exposure)")
            }
        }
    }

    @Test
    func `A surface through haze takes the haze's pixel at its distance ahead of the eye`() throws {
        let haze = Picture.Scene.Haze(.init(red: 0.5, green: 0.6, blue: 0.8), density: 0.1)
        let colour = Picture.Color(red: 0.9, green: 0.2, blue: 0.1)
        let projection = try Projection<Double>(.perspective, left: -1, right: 1, bottom: -1, top: 1, near: 1, far: 50, depth: .symmetric)
        let square = try Mesh(vertices: [Vertex([-20, -20, -7]), Vertex([20, -20, -7]), Vertex([20, 20, -7]), Vertex([-20, 20, -7])], faces: [Polygon(0, 1, 2, 3)])
        let scene = Picture.Scene(
            camera: .init(projection: projection),
            viewport: .init(llx: 0, lly: 0, urx: 160, ury: 90),
            models: [.init(square, material: .flat(colour))],
            haze: haze
        )
        let drawn = try Self.drawn([.scene(scene)])
        let expected = haze.pixel(colour.pixel, at: 7)
        #expect(drawn.pixels.allSatisfy { Tests.close($0, expected, within: 1e-5) })
        var clear = scene
        clear.haze = nil
        #expect(try Self.drawn([.scene(clear)]).pixels.allSatisfy { $0 == colour.pixel })
    }

    @Test
    func `A kaleidoscope's mirror edges show nothing from across them, and its seams lie on them`() throws {
        let white = Picture.Color(red: 1, green: 1, blue: 1)
        let red = Picture.Color(red: 1, green: 0, blue: 0)
        let center = Tests.at(80.3, 45.7)
        let content: Picture = [
            Tests.fill(Tests.rectangle(0, 0, 160, 90), red),
            Tests.fill(Tests.rectangle(80, 45, 200, 200), white),
        ]
        let plain = try Self.drawn([.layer(.init(content, effects: [.kaleidoscope(.init(center: center, segments: 2))]))])
        let far = Tests.positions(160, 90).filter { position in
            let (x, y) = (Double(position.x) + 0.5 - center[0], Double(position.y) + 0.5 - center[1])
            return (x * x + y * y).squareRoot() > 2
        }
        #expect(far.allSatisfy { Tests.at(plain, $0.x, $0.y) == white.pixel })
        let green = Picture.Color(red: 0, green: 1, blue: 0)
        let seamed = try Self.drawn([
            .layer(.init(content, effects: [.kaleidoscope(.init(center: center, segments: 2, seam: .init(green, width: 3)))]))
        ])
        #expect(Tests.close(Tests.at(seamed, 20, 45), green.pixel, within: 1e-6))
        #expect(Tests.at(seamed, 20, 40) == white.pixel)
        #expect(Tests.close(Tests.at(seamed, 80, 10), green.pixel, within: 1e-6))
        #expect(Tests.at(seamed, 75, 10) == white.pixel)
    }

    @Test
    func `Blur, haze, seams and spokes draw the same on one thread and on several`() throws {
        let now = try Self.camera(at: Vertex([0, 0, 0]), yaw: 0.05)
        let haze = Picture.Scene.Haze(.init(red: 0.3, green: 0.35, blue: 0.5), density: 0.04)
        let scene = try Self.street(now, width: 160, height: 90, haze: haze)
        let earlier = try Self.camera(at: Vertex([0.2, 0, 1]), yaw: 0.0)
        let kaleidoscope = Picture.Effect.Kaleidoscope(
            center: Tests.at(80, 45),
            segments: 6,
            rotation: Radian(0.2),
            seam: .init(.init(red: 1, green: 1, blue: 1), width: 1.5),
            spokes: .init(red: 0, green: 0, blue: 0)
        )
        let picture: Picture = [
            .layer(.init(scene.exposure(since: earlier, .bands(3)))),
            .layer(.init(scene.exposure(since: earlier, .samples(3)), effects: [.kaleidoscope(kaleidoscope)], opacity: 0.5)),
        ]
        let one = try Self.drawn(picture, threads: 1)
        for threads: Cardinal in [3, 8] {
            #expect(try Self.drawn(picture, threads: threads) == one, "\(threads) threads")
        }
    }
}
