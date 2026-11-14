import Numeric
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A pose and a model move between two placements, and a scene is blurred by how its models moved` {}
}

extension `Picture Tests`.`A pose and a model move between two placements, and a scene is blurred by how its models moved` {
    typealias Tests = `Picture Tests`
    typealias Sight = `Picture Tests`.`A camera sees a point at a place with its distance, through haze, and mixes toward another`

    @Test
    func `A pose mixed toward another keeps both ends, goes straight and turns evenly`() throws {
        let start = Picture.Scene.Camera.Pose(at: Point([0, 1, 0]), yaw: Radian(0.2))
        let end = Picture.Scene.Camera.Pose(at: Point([2, 1, -6]), yaw: Radian(0.8))
        #expect(start.interpolated(to: end, at: 0) == start)
        #expect(start.interpolated(to: end, at: 1) == end)
        let quarter = start.interpolated(to: end, at: 0.25)
        let expected = Picture.Scene.Camera.Pose(at: Point([0.5, 1, -1.5]), yaw: Radian(0.35))
        #expect((0..<9).allSatisfy { abs(quarter.rotation[$0 / 3, $0 % 3] - expected.rotation[$0 / 3, $0 % 3]) < 1e-12 })
        #expect((0..<3).allSatisfy { abs(quarter.place[$0] - expected.place[$0]) < 1e-12 })
        // The camera's view mix is the pose's.
        let lens = try Projection<Double>.perspective(fieldOfView: Radian(0.9), aspect: 1, near: 0.5, far: 100, depth: .unit)
        let mixed = Picture.Scene.Camera(projection: lens, pose: start).interpolated(to: Picture.Scene.Camera(projection: lens, pose: end), at: 0.25)
        #expect((0..<16).allSatisfy { abs(mixed.view[$0 / 4, $0 % 4] - quarter.view[$0 / 4, $0 % 4]) < 1e-12 })
        // A pose whose rotation is not one mixes entry by entry.
        let stretched = Picture.Scene.Camera.Pose(rotation: Matrix<3, 3, Double>(rows: [[2, 0, 0], [0, 1, 0], [0, 0, 1]]), place: Point([0, 0, 0]))
        let half = stretched.interpolated(to: Picture.Scene.Camera.Pose(at: Point([2, 0, 0])), at: 0.5)
        #expect(half.rotation[0, 0] == 1.5 && half.rotation[1, 1] == 1 && half.place[0] == 1)
    }

    @Test
    func `A similarity takes the anchor to the place, scaling lengths and turning angles`() {
        let anchor = Tests.at(3, -2)
        let place = Tests.at(10, 20)
        let transform = Picture.Transform(placing: anchor, at: place, turn: Radian(0.7), scale: 2.5)
        let moved = transform.applied(to: Vector([anchor[0], anchor[1]]))
        #expect(Tests.close(Tests.at(moved[0], moved[1]), place, within: 1e-12))
        let other = transform.applied(to: Vector([anchor[0] + 1, anchor[1]]))
        #expect(Tests.close(Tests.at(other[0] - moved[0], other[1] - moved[1]), Tests.at(2.5 * Double.cos(0.7), 2.5 * Double.sin(0.7)), within: 1e-12))
        #expect(Picture.Transform(placing: anchor, at: place) == .translation(x: 7, y: 22))
    }

    @Test
    func `The trapping forms of a camera are the throwing ones`() throws {
        let viewport = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 200, ury: 100)
        #expect(
            Picture.Scene.Camera.perspective(fieldOfView: Radian(0.6), aspect: 2, near: 1, far: 60, depth: .unit)
                == (try Picture.Scene.Camera(fieldOfView: Radian(0.6), aspect: 2, near: 1, far: 60, depth: .unit))
        )
        #expect(
            Picture.Scene.Camera.perspective(focal: 80, viewport: viewport, near: 0.1, far: 100, depth: .unit)
                == (try Picture.Scene.Camera(focal: 80, viewport: viewport, near: 0.1, far: 100, depth: .unit))
        )
        #expect(
            Picture.Scene.Camera.perspective(distance: 10, scale: 20, viewport: viewport, near: 0.1, far: 100, depth: .unit)
                == (try Picture.Scene.Camera(distance: 10, scale: 20, viewport: viewport, near: 0.1, far: 100, depth: .unit))
        )
        let lens = try Projection<Double>.perspective(fieldOfView: Radian(0.6), aspect: 2, near: 1, far: 60, depth: .unit)
        #expect(
            Picture.Scene.Camera.looking(at: Point([0, 0, -5]), from: Point([1, 2, 3]), projection: lens)
                == (try Picture.Scene.Camera(projection: lens, at: Point([1, 2, 3]), looking: Point([0, 0, -5])))
        )
    }

    static func scene(_ transform: Matrix<4, 4, Double>) throws -> Picture.Scene {
        let vertices: [Point::Point<3, Double>] = [Point([-2, -1, 0]), Point([3, 1, 0]), Point([1, 2, 0]), Point([-1, -2, 0])]
        let mesh = try Mesh(vertices: vertices, faces: [])
        let camera = try Sight.camera(at: Point([0, 0, 0]))
        return Picture.Scene(camera: camera, viewport: Sight.viewport, models: [.init(mesh, transform: transform, material: .flat(.init(red: 1, green: 1, blue: 1)))])
    }

    @Test
    func `A scene's exposure since an earlier placement of a model blurs along the model's way`() throws {
        let now = try Self.scene(.translation(Vector([0, 0, -10])))
        let then = try Self.scene(.translation(Vector([0, 0, -12])))
        for exposure: Picture.Exposure in [.samples(4), .bands(2)] {
            #expect(now.exposure(since: now, exposure) == Picture([.scene(now)]))
            #expect(now.exposure(since: then, shutter: 0, exposure) == Picture([.scene(now)]))
        }
        // Samples are the scene with the model placed between, at each fraction.
        let samples = now.exposure(since: then, .samples(4))
        let start = try #require(Matrix<4, 4, Double>.Rigid(then.models[0].transform, within: 1e-6))
        let end = try #require(Matrix<4, 4, Double>.Rigid(now.models[0].transform, within: 1e-6))
        let expected = Picture.exposure(samples: 4) { fraction in
            var scene = now
            scene.models[0].transform = start.interpolated(to: end, at: fraction).matrix
            return [.scene(scene)]
        }
        #expect(samples == expected)
        // The smear carries each point now to where it was seen at the earlier placement.
        let zoom = try #require(now.smear(since: then))
        for vertex in now.models[0].mesh.vertices {
            let seen = try #require(now.position(of: vertex, in: now.models[0])).point
            let was = try #require(then.position(of: vertex, in: then.models[0])).point
            #expect(Tests.close(zoom.source(of: seen, at: 1), was, within: 1e-6))
        }
        #expect(now.smear(since: now) == nil)
    }
}
