import Numeric
import Picture
import Testing

extension `Picture Tests`.`A scene places points of a model in the picture` {
    static let ramp = Picture.Gradient(evenly: [.black, .white])

    @Test
    func `A shaded surface takes most light where it faces the lamp, and the rim adds where it turns away`() {
        let toward = Vector<3, Double>([0.4, 0.55, 0.73])
        let shade = Picture.Scene.Material.Shade(ramp: Self.ramp, toward: toward)
        let length = (0.4 * 0.4 + 0.55 * 0.55 + 0.73 * 0.73).squareRoot()
        #expect(abs(shade.light(facing: toward) - 1) < 1e-12)
        var normals: [Vector<3, Double>] = []
        for a in stride(from: -1.5, through: 1.5, by: 0.1) {
            for b in stride(from: 0.0, through: 3.1, by: 0.1) {
                normals.append(Vector([Double.cos(a) * Double.sin(b), Double.sin(a), Double.cos(a) * Double.cos(b)]))
            }
        }
        #expect(normals.allSatisfy { shade.light(facing: $0) <= 1 + 1e-12 && shade.light(facing: $0) >= 0 })
        #expect(abs(shade.light(facing: Vector([0, 0, 1])) - 0.73 / length) < 1e-12)
        #expect(shade.light(facing: Vector([0, 0, -1])) == shade.light(facing: Vector([0, 0, 1])))
        #expect(shade.light(facing: Vector([-0.4, -0.55, 0.3])) == 0)
        #expect(shade.light(facing: .zero) == 0)
        let rimmed = Picture.Scene.Material.Shade(ramp: Self.ramp, toward: toward, rim: 0.5, sharpness: 2)
        let edge = Vector<3, Double>([-1, 0, 0])
        #expect(abs(rimmed.light(facing: edge) - 0.5) < 1e-12)
        #expect(abs(rimmed.light(facing: Vector([0, 0, 1])) - shade.light(facing: Vector([0, 0, 1]))) < 1e-12)
        #expect(rimmed.pixel(facing: toward) == Self.ramp.pixel(at: Float(rimmed.light(facing: toward))))
        #expect(Picture.Scene.Material.Shade(ramp: Self.ramp, toward: .zero).light(facing: Vector([0, 0, 1])) == 0)
    }
}
