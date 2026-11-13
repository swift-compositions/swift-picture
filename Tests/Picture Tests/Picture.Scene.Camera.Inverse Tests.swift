import Numeric
import Picture
import Testing

extension `Picture Tests`.`A scene places points of a model in the picture` {
    static let frame = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 1920, ury: 1080)

    static func near(_ a: Picture.Plane.Point<2>, _ b: Picture.Plane.Point<2>, within tolerance: Double = 1e-7) -> Bool {
        abs(a[0] - b[0]) <= tolerance && abs(a[1] - b[1]) <= tolerance
    }

    @Test
    func `A camera at a distance shows a unit of the world's middle plane at its scale, the origin in the middle`() throws {
        for (distance, scale) in [(14.0, 196.0), (3200, 1), (900, 0.5)] {
            let camera = try Picture.Scene.Camera(distance: distance, scale: scale, viewport: Self.frame, near: 0.5, far: 1e5, depth: .unit)
            let origin = try #require(camera.sight(of: Point([0, 0, 0]), viewport: Self.frame))
            #expect(Self.near(origin.position.point, Picture.Plane.Point<2>([960, 540])))
            #expect(abs(origin.distance - distance) < 1e-9)
            let right = try #require(camera.sight(of: Point([1, 0, 0]), viewport: Self.frame))
            let up = try #require(camera.sight(of: Point([0, 1, 0]), viewport: Self.frame))
            #expect(abs(right.position.point[0] - 960 - scale) < 1e-7 * scale && abs(right.position.point[1] - 540) < 1e-9)
            #expect(abs(540 - up.position.point[1] - scale) < 1e-7 * scale && abs(up.position.point[0] - 960) < 1e-9)
            let nearer = try #require(camera.sight(of: Point([1, 0, distance / 2]), viewport: Self.frame))
            #expect(abs(nearer.position.point[0] - 960 - 2 * scale) < 1e-7 * scale)
        }
        #expect(throws: Projection<Double>.Error.self) {
            try Picture.Scene.Camera(distance: 10, scale: 100, viewport: .init(llx: 0, lly: 0, urx: 10, ury: 0), near: 1, far: 20, depth: .unit)
        }
    }

    @Test
    func `The point under a picture point at a distance is seen there at that distance`() throws {
        let perspective = try Projection<Double>.perspective(fieldOfView: Radian(1.1), aspect: 16 / 9, near: 0.3, far: 4000, depth: .symmetric)
        let orthographic = try Projection<Double>.orthographic(width: 32, height: 18, near: -10, far: 100, depth: .unit)
        let cameras = [
            try Picture.Scene.Camera(distance: 14, scale: 196, viewport: Self.frame, near: 0.5, far: 100, depth: .unit),
            Picture.Scene.Camera(projection: perspective, at: Point([3, -2, 40]), yaw: Radian(0.4), pitch: Radian(-0.3), roll: Radian(0.2)),
            Picture.Scene.Camera(projection: orthographic, at: Point([1, 2, 3]), yaw: Radian(-1.2), pitch: Radian(0.5)),
        ]
        for camera in cameras {
            for (x, y, distance) in [(960.0, 540.0, 14.0), (0, 0, 2), (1700.5, 77.25, 300), (412, 1003, 0.9)] {
                let point = Picture.Plane.Point<2>([x, y])
                let world = try #require(camera.point(under: point, distance: distance, viewport: Self.frame))
                let sight = try #require(camera.sight(of: world, viewport: Self.frame))
                #expect(Self.near(sight.position.point, point, within: 1e-7 * Swift.max(distance, 1)))
                #expect(abs(sight.distance - distance) < 1e-9 * Swift.max(distance, 1))
                #expect(camera.placement(at: point, distance: distance, viewport: Self.frame) == .translation(Vector([world[0], world[1], world[2]])))
                let scene = Picture.Scene(camera: camera, viewport: Self.frame, models: [])
                #expect(scene.point(under: point, distance: distance) == world)
                #expect(scene.placement(at: point, distance: distance) == camera.placement(at: point, distance: distance, viewport: Self.frame))
            }
        }
        let squashed = Picture.Scene.Camera(projection: perspective, view: .scale(Vector([1, 2, 1])))
        #expect(squashed.point(under: Picture.Plane.Point<2>([10, 10]), distance: 5, viewport: Self.frame) == nil)
        #expect(cameras[0].point(under: Picture.Plane.Point<2>([10, 10]), distance: 5, viewport: .init(llx: 0, lly: 0, urx: 0, ury: 10)) == nil)
    }

    @Test
    func `An orbiting eye looks at its target from its distance, swung by yaw and pitch`() throws {
        let projection = try Projection<Double>.perspective(fieldOfView: Radian(1.15), aspect: 16 / 9, near: 0.3, far: 4000, depth: .symmetric)
        let target = Point::Point<3, Double>([4, 26, -12])
        for (yaw, pitch, roll) in [(0.0, 0.0, 0.0), (0.4, -0.2, 0.1), (-2.5, 0.7, -0.3), (1.2, 1.1, 0)] {
            let camera = Picture.Scene.Camera(projection: projection, around: target, distance: 31, yaw: Radian(yaw), pitch: Radian(pitch), roll: Radian(roll))
            let sight = try #require(camera.sight(of: target, viewport: Self.frame))
            #expect(Self.near(sight.position.point, Picture.Plane.Point<2>([960, 540]), within: 1e-8))
            #expect(abs(sight.distance - 31) < 1e-9)
            // The eye stands where a spherical orbit puts it: aside by the yaw, above by minus the pitch.
            let above = -pitch
            let place = Point::Point<3, Double>([
                target[0] + 31 * Double.sin(yaw) * Double.cos(above),
                target[1] + 31 * Double.sin(above),
                target[2] + 31 * Double.cos(yaw) * Double.cos(above),
            ])
            let standing = Picture.Scene.Camera(projection: projection, at: place, yaw: Radian(yaw), pitch: Radian(pitch), roll: Radian(roll))
            for row in 0..<4 {
                for column in 0..<4 { #expect(abs(camera.view[row, column] - standing.view[row, column]) < 1e-12) }
            }
        }
    }

    @Test
    func `An eye looking at a target sees it in the middle, with up toward the top`() throws {
        let projection = try Projection<Double>.perspective(fieldOfView: Radian(1), aspect: 16 / 9, near: 0.1, far: 100, depth: .unit)
        let camera = try Picture.Scene.Camera(projection: projection, at: Point([3, 4, 5]), looking: Point([-1, 0, 2]))
        let sight = try #require(camera.sight(of: Point([-1, 0, 2]), viewport: Self.frame))
        #expect(Self.near(sight.position.point, Picture.Plane.Point<2>([960, 540]), within: 1e-8))
        #expect(abs(sight.distance - (16.0 + 16 + 9).squareRoot()) < 1e-9)
        let higher = try #require(camera.sight(of: Point([-1, 1, 2]), viewport: Self.frame))
        #expect(higher.position.point[1] < 540)
        #expect(throws: Matrix<4, 4, Double>.Error.self) {
            try Picture.Scene.Camera(projection: projection, at: Point([0, 0, 0]), looking: Point([0, 0, 0]))
        }
    }
}
