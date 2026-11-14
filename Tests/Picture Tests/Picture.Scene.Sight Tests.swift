import Numeric
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A camera sees a point at a place with its distance, through haze, and mixes toward another` {}
}

extension `Picture Tests`.`A camera sees a point at a place with its distance, through haze, and mixes toward another` {
    typealias Tests = `Picture Tests`

    static func camera(at place: Point::Point<3, Double>, yaw: Double = 0, pitch: Double = 0) throws -> Picture.Scene.Camera {
        let projection = try Projection<Double>.perspective(fieldOfView: Radian(0.9), aspect: 16 / 9, near: 0.5, far: 200, depth: .unit)
        return Picture.Scene.Camera(projection: projection, at: place, yaw: Radian(yaw), pitch: Radian(pitch))
    }

    static let viewport = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 1920, ury: 1080)

    static let points: [Point::Point<3, Double>] = [
        Point([0, 0, -5]), Point([3, -1, -40]), Point([-7, 2.5, -0.7]), Point([0.2, 0.1, -0.3]), Point([1, 1, 4]), Point([-30, 4, -150]),
    ]

    @Test
    func `A point's place agrees with the scene's, and its distance with the view matrix`() throws {
        let camera = try Self.camera(at: Point([1, 2, 3]), yaw: 0.3, pitch: -0.1)
        let model = Matrix<4, 4, Double>.translation(Vector([0.5, -1, 0.25]))
        let mesh = try Mesh(vertices: Self.points, faces: [])
        let scene = Picture.Scene(camera: camera, viewport: Self.viewport, models: [.init(mesh, transform: model, material: .flat(.init(red: 1, green: 1, blue: 1)))])
        for point in Self.points {
            let eye = camera.view.multiplied(by: model).applied(to: Vector([point[0], point[1], point[2], 1]))
            #expect(Tests.close(camera.distance(of: point, in: model), -eye[2], within: 1e-12))
            let sight = camera.sight(of: point, in: model, viewport: Self.viewport)
            #expect(sight?.position == scene.position(of: point, in: scene.models[0]))
            #expect(scene.sight(of: point, in: scene.models[0]) == sight)
            if let sight {
                #expect(Tests.close(sight.distance, -eye[2], within: 1e-12))
                #expect(sight.ahead == (sight.distance >= 0.5 - 1e-9))
                #expect(Tests.close(camera.distance(at: sight.position.depth) ?? .nan, sight.distance, within: 1e-6 * sight.distance))
            }
        }
    }

    @Test
    func `Haze is the surface at no distance and tends to its colour far away, never falling`() {
        let haze = Picture.Scene.Haze(.init(red: 0.6, green: 0.7, blue: 0.9), density: 0.05)
        let surface = Tests.pixel(0.8, 0.1, 0.05, 1)
        #expect(haze.pixel(surface, at: 0) == surface)
        #expect(haze.pixel(surface, at: -3) == surface)
        #expect(Tests.close(haze.pixel(surface, at: 1e4), haze.color.pixel, within: 1e-6))
        #expect(Tests.close(haze.share(at: 20), 1 - Double.exp(-1), within: 1e-12))
        let shares = stride(from: 0.0, through: 300, by: 0.5).map(haze.share(at:))
        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(Picture.Scene.Haze(haze.color, density: 0).pixel(surface, at: 50) == surface)
    }

    @Test
    func `A camera mixed toward another keeps both ends and a rigid view, moving and turning evenly`() throws {
        let start = try Self.camera(at: Point([0, 1, 0]), yaw: 0.1)
        let end = try Self.camera(at: Point([2, 1, -6]), yaw: 0.7, pitch: 0.2)
        #expect(start.interpolated(to: end, at: 0) == start)
        #expect(start.interpolated(to: end, at: 1) == end)
        #expect(start.interpolated(to: start, at: 0.37) == start)
        let half = start.interpolated(to: end, at: 0.5)
        let rotation = Matrix<3, 3, Double>(rows: InlineArray { row in InlineArray { column in half.view[row, column] } })
        let product = rotation.multiplied(by: rotation.transposed)
        #expect([0, 1, 2].allSatisfy { row in [0, 1, 2].allSatisfy { column in abs(product[row, column] - (row == column ? 1 : 0)) < 1e-12 } })
        let place = rotation.transposed.applied(to: Vector([half.view[0, 3], half.view[1, 3], half.view[2, 3]]))
        #expect(Tests.close(-place[0], 1, within: 1e-12) && Tests.close(-place[1], 1, within: 1e-12) && Tests.close(-place[2], -3, within: 1e-12))
        let quarter = start.interpolated(to: end, at: 0.25)
        let back = quarter.interpolated(to: half, at: 1)
        #expect(back == half)
        let yawing = try Self.camera(at: Point([0, 0, 0]), yaw: 0.2)
        let yawed = try Self.camera(at: Point([0, 0, 0]), yaw: 0.8)
        let between = yawing.interpolated(to: yawed, at: 0.25)
        let expected = try Self.camera(at: Point([0, 0, 0]), yaw: 0.35)
        #expect((0..<16).allSatisfy { abs(between.view[$0 / 4, $0 % 4] - expected.view[$0 / 4, $0 % 4]) < 1e-12 })
    }

    @Test
    func `A scene seen by a camera that did not move, or through a closed shutter, is itself`() throws {
        let camera = try Self.camera(at: Point([0, 0, 0]))
        let mesh = try Mesh(vertices: [Point::Point<3, Double>([0, 0, -5]), Point([1, 0, -5]), Point([0, 1, -5])], faces: [Polygon(0, 1, 2)])
        let scene = Picture.Scene(camera: camera, viewport: Self.viewport, models: [.init(mesh, material: .flat(.init(red: 1, green: 0, blue: 0)))])
        var earlier = scene
        earlier.camera = try Self.camera(at: Point([0, 0, 1]))
        for exposure: Picture.Exposure in [.samples(6), .bands(4), .samples(0), .bands(0)] {
            #expect(scene.exposure(since: scene, exposure) == Picture([.scene(scene)]))
            #expect(scene.exposure(since: earlier, shutter: 0, exposure) == Picture([.scene(scene)]))
        }
        #expect(scene.exposure(since: earlier, .samples(3)) != Picture([.scene(scene)]))
    }

    @Test
    func `A scene's smear carries each point now to where it was seen when the shutter opened`() throws {
        let now = try Self.camera(at: Point([0, 0, 0]))
        let then = try Self.camera(at: Point([0, 0, 2]))
        let vertices: [Point::Point<3, Double>] = [Point([-2, -1, -10]), Point([3, 1, -10]), Point([1, 2, -10]), Point([-1, -2, -10])]
        let mesh = try Mesh(vertices: vertices, faces: [])
        let scene = Picture.Scene(camera: now, viewport: Self.viewport, models: [.init(mesh, material: .flat(.init(red: 1, green: 1, blue: 1)))])
        var opened = scene
        opened.camera = then
        let zoom = try #require(scene.smear(since: opened))
        for vertex in vertices {
            let seen = try #require(scene.position(of: vertex, in: scene.models[0])).point
            let was = try #require(then.sight(of: vertex, viewport: Self.viewport)).position.point
            #expect(Tests.close(zoom.source(of: seen, at: 1), was, within: 1e-6))
        }
        #expect(Tests.close(zoom.center, Tests.at(960, 540), within: 1e-6))
        #expect(scene.smear(since: scene) == nil)
    }
}

extension `Picture Tests`.`A camera sees a point at a place with its distance, through haze, and mixes toward another` {
    @Test
    func `A view that is not rigid mixes entry by entry, and lenses of another kind switch at a share of one`() throws {
        let lens = try Projection<Double>.perspective(fieldOfView: Radian(0.9), aspect: 16 / 9, near: 0.5, far: 200, depth: .unit)
        let flat = try Projection<Double>.orthographic(width: 4, height: 3, near: 0, far: 100, depth: .unit)
        let symmetric = try Projection<Double>.perspective(fieldOfView: Radian(0.9), aspect: 16 / 9, near: 0.5, far: 200, depth: .symmetric)
        let stretched = Matrix<4, 4, Double>.scale(Vector([2, 1, 1]))
        let moved = Matrix<4, 4, Double>.translation(Vector([1, -2, 3]))
        let start = Picture.Scene.Camera(projection: lens, view: stretched)
        let end = Picture.Scene.Camera(projection: lens, view: moved)
        let quarter = start.interpolated(to: end, at: 0.25)
        #expect((0..<16).allSatisfy { quarter.view[$0 / 4, $0 % 4] == stretched[$0 / 4, $0 % 4] + (moved[$0 / 4, $0 % 4] - stretched[$0 / 4, $0 % 4]) * 0.25 })
        for other in [flat, symmetric] {
            let away = Picture.Scene.Camera(projection: other, view: moved)
            #expect(start.interpolated(to: away, at: 0.5).projection == lens)
            #expect(start.interpolated(to: away, at: 0.999).projection == lens)
            #expect(start.interpolated(to: away, at: 1).projection == other)
        }
    }
}
