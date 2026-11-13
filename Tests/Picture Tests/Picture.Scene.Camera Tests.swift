import Picture
import Testing

extension `Picture Tests`.`A scene places points of a model in the picture` {
    @Test
    func `A lens is the perspective projection of the same arguments`() throws {
        let field = Radian(0.6)
        let camera = try Picture.Scene.Camera(fieldOfView: field, aspect: 16 / 9, near: 1, far: 60, depth: .unit)
        let projection = try Projection<Double>.perspective(fieldOfView: field, aspect: 16 / 9, near: 1, far: 60, depth: .unit)
        #expect(camera == Picture.Scene.Camera(projection: projection))
        #expect(throws: Projection<Double>.Error.self) {
            try Picture.Scene.Camera(fieldOfView: field, aspect: 1, near: -1, far: 60, depth: .unit)
        }
    }

    @Test
    func `An eye at a place, turned by three angles, sees what lies along its line of sight ahead`() throws {
        let projection = try Projection<Double>(.perspective, left: -1, right: 1, bottom: -1, top: 1, near: 1, far: 100, depth: .unit)
        let still = Picture.Scene.Camera(projection: projection, at: Point([0, 0, 0]))
        #expect(still.view == .identity)
        let placed = Picture.Scene.Camera(projection: projection, at: Point([1, 2, 3]))
        #expect(placed.view == .translation(Vector([-1, -2, -3])))
        let quarter = Radian(Double.pi / 2)
        func ahead(_ camera: Picture.Scene.Camera, _ point: Point::Point<3, Double>) -> Vector<4, Double> {
            camera.view.applied(to: Vector([point[0], point[1], point[2], 1]))
        }
        let left = Picture.Scene.Camera(projection: projection, at: Point([1, 2, 3]), yaw: quarter)
        let seen = ahead(left, Point([-4, 2, 3]))
        #expect(abs(seen[0]) < 1e-12 && abs(seen[1]) < 1e-12 && abs(seen[2] + 5) < 1e-12)
        let up = Picture.Scene.Camera(projection: projection, at: Point([0, 0, 0]), pitch: quarter)
        let above = ahead(up, Point([0, 7, 0]))
        #expect(abs(above[0]) < 1e-12 && abs(above[1]) < 1e-12 && abs(above[2] + 7) < 1e-12)
        let banked = Picture.Scene.Camera(projection: projection, at: Point([0, 0, 0]), roll: quarter)
        let right = ahead(banked, Point([1, 0, -5]))
        #expect(abs(right[0]) < 1e-12 && abs(right[1] + 1) < 1e-12 && right[2] == -5)
    }
}
