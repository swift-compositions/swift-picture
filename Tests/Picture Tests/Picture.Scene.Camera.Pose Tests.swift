import Numeric
import Picture
import Testing

extension `Picture Tests`.`A scene places points of a model in the picture` {
    static func near(_ a: Vector<3, Double>, _ b: Vector<3, Double>) -> Bool {
        (0..<3).allSatisfy { abs(a[$0] - b[$0]) < 1e-9 }
    }

    @Test
    func `A camera's pose says where its eye stands and which way it looks`() throws {
        let projection = try Projection<Double>.perspective(fieldOfView: Radian(1), aspect: 1, near: 1, far: 100, depth: .unit)
        let place = Point<3, Double>([1, 2, 3])
        let quarter = Radian<Double>(Double.pi / 2)
        let pose = try #require(Picture.Scene.Camera(projection: projection, at: place, yaw: quarter).pose)
        #expect(Self.near(Vector([pose.place[0], pose.place[1], pose.place[2]]), Vector([1, 2, 3])))
        #expect(Self.near(pose.direction, Vector([-1, 0, 0])))
        #expect(Self.near(pose.up, Vector([0, 1, 0])))
        let up = Picture.Scene.Camera.Pose(at: place, pitch: quarter)
        #expect(Self.near(up.direction, Vector([0, 1, 0])))
        #expect(Picture.Scene.Camera(projection: projection, view: .scale(Vector([1, 2, 1]))).pose == nil)
        let orbit = Picture.Scene.Camera.Pose(around: Point([0, 0, -10]), distance: 4, yaw: Radian(0.3), pitch: Radian(-0.2))
        #expect(
            Picture.Scene.Camera(projection: projection, pose: orbit) == Picture.Scene.Camera(projection: projection, around: Point([0, 0, -10]), distance: 4, yaw: Radian(0.3), pitch: Radian(-0.2))
        )
        let toward = Vector<3, Double>([0 - orbit.place[0], 0 - orbit.place[1], -10 - orbit.place[2]])
        #expect(Self.near(orbit.direction, Vector([toward[0] / 4, toward[1] / 4, toward[2] / 4])))
        let looking = try Picture.Scene.Camera.Pose(at: Point([3, 4, 5]), looking: Point([3, 4, 0]))
        #expect(Self.near(looking.direction, Vector([0, 0, -1])))
        #expect(Picture.Scene.Camera.Pose(Picture.Scene.Camera(projection: projection, pose: looking).view).map { Self.near($0.direction, looking.direction) } == true)
    }

    @Test
    func `A camera takes a field of view or a focal length with a pose`() throws {
        let viewport = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 200, ury: 100)
        let pose = Picture.Scene.Camera.Pose(at: Point([0, 0, 5]))
        let focal = try Picture.Scene.Camera(focal: 80, viewport: viewport, near: 0.1, far: 100, depth: .unit, pose: pose)
        let middle = try #require(focal.sight(of: Point([0, 0, 4]), viewport: viewport))
        let aside = try #require(focal.sight(of: Point([1, 0, 4]), viewport: viewport))
        #expect(abs(aside.position.point[0] - middle.position.point[0] - 80) < 1e-9)
        #expect(abs(middle.position.point[0] - 100) < 1e-9 && abs(middle.position.point[1] - 50) < 1e-9)
        let field = try Picture.Scene.Camera(fieldOfView: Radian(1), aspect: 2, near: 0.1, far: 100, depth: .unit, pose: pose)
        #expect(field == (try Picture.Scene.Camera(fieldOfView: Radian(1), aspect: 2, near: 0.1, far: 100, depth: .unit, view: pose.view)))
        let scaled = try Picture.Scene.Camera(distance: 5, scale: 16, viewport: viewport, near: 0.1, far: 100, depth: .unit)
        #expect(scaled == (try Picture.Scene.Camera(focal: 80, viewport: viewport, near: 0.1, far: 100, depth: .unit, pose: pose)))
    }

    @Test
    func `A ball's radius on the picture is its silhouette, not its radius over its distance`() throws {
        let viewport = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 400, ury: 200)
        let camera = try Picture.Scene.Camera(focal: 100, viewport: viewport, near: 0.5, far: 50, depth: .unit)
        let ahead = try #require(camera.radius(of: 2, at: Point([0, 0, -5]), viewport: viewport))
        #expect(abs(ahead - 100 * 2 / (25.0 - 4).squareRoot()) < 1e-9)
        let aside = try #require(camera.radius(of: 2, at: Point([3, 0, -5]), viewport: viewport))
        let (sine, cosine) = (2 / 34.0.squareRoot(), 5 / 34.0.squareRoot())
        #expect(abs(aside - 100 * sine / (cosine * cosine - sine * sine).squareRoot()) < 1e-9)
        #expect(aside > 100 * 2 / 5 + 1)
        #expect(camera.radius(of: 2, at: Point([0, 0, -1]), viewport: viewport) == nil)
        #expect(camera.radius(of: 2, at: Point([0, 0, 5]), viewport: viewport) == nil)
        #expect(camera.radius(of: -1, at: Point([0, 0, -5]), viewport: viewport) == nil)
        let flat = Picture.Scene.Camera(projection: try .orthographic(width: 4, height: 4, near: 0, far: 10, depth: .unit))
        #expect(flat.radius(of: 1, at: Point([1, 1, -3]), viewport: .init(llx: 0, lly: 0, urx: 40, ury: 40)) == 10)
    }

    @Test
    func `A shade's light is its lamp's cosine and its rim apart, and the ramp read at their sum`() {
        let toward = Vector<3, Double>([0.4, 0.55, 0.73])
        let shade = Picture.Scene.Material.Shade(ramp: Self.ramp, toward: toward, rim: 0.5, sharpness: 2)
        for normal in [Vector<3, Double>([0, 0, 1]), Vector([-1, 0, 0.1]), Vector([0.3, -0.2, -0.9]), Vector([0.4, 0.55, 0.73])] {
            #expect(shade.light(facing: normal) == shade.cosine(facing: normal) + shade.rim(facing: normal))
            #expect(shade.pixel(facing: normal) == shade.pixel(at: shade.light(facing: normal)))
        }
        #expect(shade.rim(facing: Vector([0, 0, 1])) == 0)
        #expect(abs(shade.rim(facing: Vector([-1, 0, 0])) - 0.5) < 1e-12)
        #expect(shade.cosine(facing: Vector([-1, 0, 0])) == 0)
        #expect(abs(shade.cosine(facing: toward) - 1) < 1e-12)
        #expect(shade.cosine(facing: .zero) == 0 && shade.rim(facing: .zero) == 0)
    }
}
