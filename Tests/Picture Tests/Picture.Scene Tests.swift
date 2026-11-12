import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A scene places points of a model in the picture` {}
}

extension `Picture Tests`.`A scene places points of a model in the picture` {
    typealias Tests = `Picture Tests`

    static func translation(_ x: Double, _ y: Double, _ z: Double) -> Matrix<4, 4, Double> {
        Matrix(rows: [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]])
    }

    static func viewport() -> Geometry<Double, Picture.Space>.Rectangle {
        .init(llx: 100, lly: 50, urx: 300, ury: 150)
    }

    static func model(_ transform: Matrix<4, 4, Double> = .identity) -> Picture.Scene.Model {
        Picture.Scene.Model(.empty, transform: transform, material: .flat(.white))
    }

    static func flat() throws -> Picture.Scene {
        let projection = try Projection<Double>.orthographic(width: 4, height: 2, near: 0, far: 10, depth: .unit)
        return Picture.Scene(camera: .init(projection: projection), viewport: viewport(), models: [])
    }

    static func deep() throws -> Picture.Scene {
        let projection = try Projection<Double>(.perspective, left: -1, right: 1, bottom: -1, top: 1, near: 1, far: 100, depth: .unit)
        return Picture.Scene(camera: .init(projection: projection), viewport: viewport(), models: [])
    }

    @Test
    func `The view volume fills the viewport, with up in eye space toward smaller y`() throws {
        let scene = try Self.flat()
        #expect(scene.camera.view == .identity)
        #expect(scene.position(of: Point([0, 0, -5]), in: Self.model())?.point == Tests.at(200, 100))
        #expect(scene.position(of: Point([-2, 1, -5]), in: Self.model())?.point == Tests.at(100, 50))
        #expect(scene.position(of: Point([2, -1, -5]), in: Self.model())?.point == Tests.at(300, 150))
        #expect(scene.position(of: Point([1, 0.5, -5]), in: Self.model())?.point == Tests.at(250, 75))
        #expect(scene.position(of: Point([4, 0, -5]), in: Self.model())?.point == Tests.at(400, 100))
    }

    @Test
    func `Depth is the projection's: the near plane at its lower bound, nearer points lower`() throws {
        let scene = try Self.flat()
        #expect(scene.position(of: Point([0, 0, 0]), in: Self.model())?.depth == 0)
        #expect(scene.position(of: Point([0, 0, -10]), in: Self.model())?.depth == 1)
        #expect(scene.position(of: Point([0, 0, -2.5]), in: Self.model())?.depth == 0.25)
        let deep = try Self.deep()
        let near = try #require(deep.position(of: Point([0, 0, -2]), in: Self.model()))
        let far = try #require(deep.position(of: Point([0, 0, -50]), in: Self.model()))
        #expect(near.depth < far.depth)
        #expect(Tests.close(try #require(deep.position(of: Point([0, 0, -1]), in: Self.model())).depth, 0))
    }

    @Test
    func `In perspective, points on one line through the eye share a place, and nothing at or behind the eye has one`() throws {
        let scene = try Self.deep()
        let near = try #require(scene.position(of: Point([0.5, 0.25, -1]), in: Self.model()))
        let far = try #require(scene.position(of: Point([5, 2.5, -10]), in: Self.model()))
        #expect(Tests.close(near.point, Tests.at(250, 87.5)))
        #expect(Tests.close(far.point, near.point))
        #expect(scene.position(of: Point([0.5, 0.25, 0]), in: Self.model()) == nil)
        #expect(scene.position(of: Point([0.5, 0.25, 3]), in: Self.model()) == nil)
        #expect(scene.camera.normalized(Point([0.5, 0.25, 3])) == nil)
    }

    @Test
    func `A point goes through the model's transform, then the view, then the projection`() throws {
        var scene = try Self.flat()
        let moved = Self.model(Self.translation(1, 0.5, -5))
        #expect(scene.position(of: Point([0, 0, 0]), in: moved)?.point == Tests.at(250, 75))
        scene.camera.view = Self.translation(-1, -0.5, 0)
        #expect(scene.position(of: Point([0, 0, 0]), in: moved)?.point == Tests.at(200, 100))
        let scale = Matrix<4, 4, Double>(rows: [[2, 0, 0, 0], [0, 2, 0, 0], [0, 0, 2, 0], [0, 0, 0, 1]])
        scene.camera.view = Self.translation(0, 0, -5).multiplied(by: scale)
        #expect(scene.position(of: Point([0.5, 0.25, 0]), in: Self.model(Self.translation(0.5, 0.25, 0)))?.point == Tests.at(300, 50))
        let point = Point<3, Double>([0.3, -0.2, 0.1])
        let eye = scene.camera.view.multiplied(by: moved.transform).applied(to: Vector([0.3, -0.2, 0.1, 1]))
        let clip = scene.camera.clip(point, in: moved.transform)
        let direct = scene.camera.projection.clip(Point([eye[0], eye[1], eye[2]]))
        (0..<4).forEach { index in #expect(Tests.close(clip[index], direct[index])) }
        #expect(clip[3] == 1)
    }

    @Test
    func `A direction goes through the view and the model without their translation and comes out at unit length`() throws {
        var camera = try Self.flat().camera
        #expect(camera.direction(Vector([0, 0, 5])) == Vector([0, 0, 1]))
        #expect(camera.direction(Vector([3, 4, 0])) == Vector([0.6, 0.8, 0]))
        #expect(camera.direction(Vector([3, 4, 0]), in: Self.translation(9, 9, 9)) == Vector([0.6, 0.8, 0]))
        camera.view = Matrix(rows: [[0, -1, 0, 7], [1, 0, 0, 7], [0, 0, 1, 7], [0, 0, 0, 1]])
        #expect(camera.direction(Vector([2, 0, 0])) == Vector([0, 1, 0]))
        #expect(camera.direction(Vector([0, 2, 0]), in: Self.translation(1, 2, 3)) == Vector([-1, 0, 0]))
        #expect(camera.direction(.zero) == .zero)
        #expect(camera.direction(Vector([1, 2, 3]), in: .zero) == .zero)
        let stretch = Matrix<4, 4, Double>(rows: [[2, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
        let turned = camera.direction(Vector([1, 1, 0]), in: stretch)
        #expect(Tests.close(turned[0], -1 / 5.0.squareRoot()))
        #expect(Tests.close(turned[1], 2 / 5.0.squareRoot()))
        #expect(turned[2] == 0)
    }

    @Test
    func `Glass reads the picture behind it aside by its bend times the normal's x and minus its y`() {
        let glass = Picture.Scene.Material.Glass(bend: 20)
        #expect(glass.tint == .clear)
        #expect(glass.offset(for: Vector([0, 0, 1])) == .zero)
        #expect(glass.offset(for: Vector([1, 0, 0])) == Vector([20, 0]))
        #expect(glass.offset(for: Vector([0, 1, 0])) == Vector([0, -20]))
        #expect(glass.offset(for: Vector([0.6, -0.8, 0])) == Vector([12, 16]))
        #expect(Picture.Scene.Material.Glass(bend: 0).offset(for: Vector([0.6, -0.8, 0])) == .zero)
    }

    @Test
    func `Glass shows what it reads under a coat of its tint`() {
        let behind = Tests.pixel(0.25, 0.5, 0.75, 1)
        #expect(Picture.Scene.Material.Glass(bend: 20).pixel(over: behind) == behind)
        #expect(Picture.Scene.Material.Glass(bend: 20).pixel(over: .transparent) == .transparent)
        let tinted = Picture.Scene.Material.Glass(bend: 20, tint: .init(red: 1, green: 0, blue: 0, alpha: 0.5))
        #expect(tinted.pixel(over: behind) == Tests.pixel(0.625, 0.25, 0.375, 1))
        #expect(Picture.Scene.Material.Glass(bend: 20, tint: .black).pixel(over: behind) == Tests.pixel(0, 0, 0, 1))
    }

    @Test
    func `A scene holds its models in order with their meshes and materials`() throws {
        let torus = Mesh<Point<3, Double>>.torus(major: 2, minor: 0.5, segments: 8, sides: 4)
        let glass = Picture.Scene.Model(torus, material: .glass(.init(bend: 12)))
        let wire = Picture.Scene.Model(torus, transform: Self.translation(1, 0, 0), material: .wireframe(.white, width: 1.5))
        let dots = Picture.Scene.Model(torus, material: .points(.white, radius: 2))
        var scene = try Self.flat()
        scene.models = [glass, wire, dots]
        #expect(glass.transform == .identity)
        #expect(scene.models == [glass, wire, dots])
        #expect(scene != (try Self.flat()))
        #expect(glass != dots)
        #expect(Picture([.scene(scene)]) == Picture([.scene(scene)]))
    }
}
