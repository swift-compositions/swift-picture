import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `Short forms are the long forms they stand for` {}
}

extension `Picture Tests`.`Short forms are the long forms they stand for` {
    typealias Tests = `Picture Tests`

    @Test
    func `A transform moves, scales or turns about a point that stays where it is`() {
        #expect(Picture.Transform.translation(x: 3, y: -4) == Picture.Transform(rows: [[1, 0, 3], [0, 1, -4]]))
        let (factor, x, y) = (1.37, 812.4, -33.9)
        #expect(Picture.Transform.scale(factor, about: Tests.at(x, y)) == Picture.Transform(rows: [[factor, 0, x - factor * x], [0, factor, y - factor * y]]))
        let turn = Picture.Transform.rotation(Radian(Double.pi / 2), about: Tests.at(10, 20))
        let kept = turn.applied(to: Vector([10, 20]))
        #expect(Tests.close(kept[0], 10) && Tests.close(kept[1], 20))
        let moved = turn.applied(to: Vector([11, 20]))
        #expect(Tests.close(moved[0], 10) && Tests.close(moved[1], 21))
        #expect(turn == .rotation(Double.pi / 2, about: Vector([10, 20])))
    }

    @Test
    func `A fill and a stroke are shapes with only that`() {
        let path = Tests.square(4)
        #expect(Picture.Element.fill(path, .solid(.white)) == .shape(Picture.Shape(path, fill: .init(.solid(.white)))))
        #expect(Picture.Element.fill(path, .solid(.white), rule: .evenodd) == .shape(Picture.Shape(path, fill: .init(.solid(.white), rule: .evenodd))))
        let pen = Picture.Plane.Path.Stroke(width: 3, join: .round, cap: .round)
        let stroke = Picture.Element.shape(Picture.Shape(path, stroke: .init(.solid(.black), pen: pen)))
        #expect(Picture.Element.stroke(path, .solid(.black), pen: pen) == stroke)
        #expect(Picture.Element.stroke(path, .solid(.black), width: 3, join: .round, cap: .round) == stroke)
    }

    @Test
    func `Six hexadecimal digits are three bytes over 255`() {
        (0...255).forEach { level in
            let value = UInt32(level)
            let color = Picture.Color(hex: value << 16 | (255 - value) << 8 | value)
            let byte = Float(level) / 255
            #expect(color == Picture.Color(red: byte, green: Float(255 - level) / 255, blue: byte))
        }
        #expect(Picture.Color(hex: 0xFF00_0000) == .black)
        #expect(Picture.Color(hex: 0xF4692F, alpha: 0.5).alpha == 0.5)
    }

    @Test
    func `A hexadecimal string is read as CSS writes it`() {
        #expect(Picture.Color(hex: "#F4692F") == Picture.Color(hex: 0xF4692F))
        #expect(Picture.Color(hex: "f4692f", alpha: 0.25) == Picture.Color(hex: 0xF4692F, alpha: 0.25))
        #expect(Picture.Color(hex: "#FFF") == .white)
        #expect(Picture.Color(hex: "#F4692") == nil)
        #expect(Picture.Color(hex: "plum") == nil)
    }

    @Test
    func `Alpha is replaced, or multiplied by an opacity, and nothing is clamped`() {
        let color = Picture.Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        #expect(color.with(alpha: 0.1) == Picture.Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.1))
        #expect(color.faded(by: 0.5) == color.with(alpha: 0.4))
        #expect(color.faded(by: 1) == color)
        #expect(color.faded(by: 2) == color.with(alpha: 1.6))
        #expect(color.faded(by: 0.5).pixel.alpha == color.pixel.alpha * 0.5)
    }

    @Test
    func `A mix as written goes straight between the components, alpha too`() {
        let from = Picture.Color(red: 0, green: 1, blue: 0.5, alpha: 1)
        let to = Picture.Color(red: 1, green: 0, blue: 0.5, alpha: 0)
        #expect(from.mixed(inSRGBTo: to, at: 0) == from)
        #expect(from.mixed(inSRGBTo: to, at: 1) == to)
        #expect(from.mixed(inSRGBTo: to, at: 0.25) == Picture.Color(red: 0.25, green: 0.75, blue: 0.5, alpha: 0.75))
        #expect(from.mixed(inSRGBTo: to, at: 2) == Picture.Color(red: 2, green: -1, blue: 0.5, alpha: -1))
    }
}
