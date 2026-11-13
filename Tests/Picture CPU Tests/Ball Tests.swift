import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests`.`A renderer draws a scene straight onto what is behind, the nearest surface showing` {
    @Test
    func `A ball is drawn as wide across as the camera's radius of it says`() throws {
        let viewport = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 400, ury: 200)
        let camera = try Picture.Scene.Camera(focal: 100, viewport: viewport, near: 0.5, far: 50, depth: .unit)
        let ball = Mesh<Vertex>.sphere(radius: 2, meridians: 128, parallels: 64)
        for center in [Vertex([0, 0, -5]), Vertex([3, 0, -5])] {
            let model = Picture.Scene.Model(ball, transform: .translation(Vector([center[0], center[1], center[2]])), material: .flat(.white))
            let scene = Picture.Scene(camera: camera, viewport: viewport, models: [model])
            let raster = try Tests.drawn([.scene(scene)], on: Tests.canvas(400, 200))
            var widest = 0.0
            for column in 0..<UInt(400) {
                let height = (0..<UInt(200)).reduce(0.0) { $0 + Double(Tests.at(raster, column, $1).alpha) }
                widest = Swift.max(widest, height)
            }
            let radius = try #require(camera.radius(of: 2, at: center, viewport: viewport))
            #expect(abs(widest - 2 * radius) < 1, "drawn \(widest), radius \(radius)")
        }
        let naive = 100 * 2 / 5.0
        let aside = try #require(camera.radius(of: 2, at: Vertex([3, 0, -5]), viewport: viewport))
        #expect(2 * (aside - naive) > 4)
    }
}
