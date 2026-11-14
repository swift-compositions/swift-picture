import Color_Standard
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A colour has a place in Oklab and a gradient can go through it` {}
}

extension `Picture Tests`.`A colour has a place in Oklab and a gradient can go through it` {
    typealias Tests = `Picture Tests`

    static let orange = Picture.Color(red: 0.96, green: 0.41, blue: 0.18)
    static let violet = Picture.Color(red: 0.48, green: 0.22, blue: 0.95)

    static func close(_ a: Picture.Color, _ b: Picture.Color, within tolerance: Float = 1e-4) -> Bool {
        Tests.close(a.red, b.red, within: tolerance) && Tests.close(a.green, b.green, within: tolerance)
            && Tests.close(a.blue, b.blue, within: tolerance) && Tests.close(a.alpha, b.alpha, within: tolerance)
    }

    @Test
    func `White is lightness one, black is lightness zero, and neither has a hue`() {
        let white = Picture.Color.white.oklab
        #expect(Tests.close(white.l, 1, within: 1e-4))
        #expect(Tests.close(white.a, 0, within: 1e-4))
        #expect(Tests.close(white.b, 0, within: 1e-4))
        let black = Picture.Color.black.oklab
        #expect(Tests.close(black.l, 0, within: 1e-6))
        #expect(Tests.close(black.a, 0, within: 1e-6))
        #expect(Tests.close(black.b, 0, within: 1e-6))
    }

    @Test
    func `A colour written back from its place in Oklab is the colour, and alpha is the one given`() {
        for color in [Self.orange, Self.violet, .white, .black, Picture.Color(red: 0, green: 1, blue: 0), Picture.Color(gray: 0.5)] {
            #expect(Self.close(Picture.Color(color.oklab), color))
        }
        #expect(Picture.Color(Self.orange.oklab, alpha: 0.25).alpha == 0.25)
        #expect(Picture.Color(Self.orange.oklab).alpha == 1)
    }

    @Test
    func `Components outside 0…1 are held there on the way in and on the way out`() {
        #expect(Picture.Color(red: 2, green: -1, blue: 0).oklab == Picture.Color(red: 1, green: 0, blue: 0).oklab)
        let beyond = Picture.Color(.init(l: 0.7, a: 0.4, b: 0.4))
        for component in [beyond.red, beyond.green, beyond.blue] {
            #expect(component >= 0 && component <= 1)
        }
    }

    @Test
    func `Halfway from black to white in Oklab is the gray of half the lightness, darker than halfway in linear light`() {
        let middle = Picture.Color.black.interpolated(inOklabTo: .white, at: 0.5)
        #expect(Tests.close(middle.oklab.l, 0.5, within: 1e-4))
        #expect(Tests.close(middle.red, middle.green, within: 1e-4))
        #expect(Tests.close(middle.green, middle.blue, within: 1e-4))
        // Half the lightness is an eighth of the light.
        #expect(Tests.close(middle.linear.color.green, 0.125, within: 1e-3))
    }

    @Test
    func `A mix starts at the one colour and ends at the other, and alpha goes along`() {
        let clear = Picture.Color(red: Self.violet.red, green: Self.violet.green, blue: Self.violet.blue, alpha: 0)
        #expect(Self.close(Self.orange.interpolated(inOklabTo: clear, at: 0), Self.orange))
        #expect(Self.close(Self.orange.interpolated(inOklabTo: clear, at: 1), clear))
        #expect(Tests.close(Self.orange.interpolated(inOklabTo: clear, at: 0.25).alpha, 0.75))
        let middle = Self.orange.interpolated(inOklabTo: Self.violet, at: 0.5).oklab
        let (from, to) = (Self.orange.oklab, Self.violet.oklab)
        #expect(Tests.close(middle.l, (from.l + to.l) / 2, within: 1e-4))
        #expect(Tests.close(middle.a, (from.a + to.a) / 2, within: 1e-4))
        #expect(Tests.close(middle.b, (from.b + to.b) / 2, within: 1e-4))
    }

    @Test
    func `A gradient through Oklab has the same stops and, between each two, equal steps of their mixes`() {
        let gradient = Picture.Gradient([
            .init(offset: 0, color: Self.orange), .init(offset: 0.5, color: Self.violet), .init(offset: 1, color: .white),
        ])
        let through = gradient.oklab(steps: 4)
        #expect(through.stops.count == 9)
        #expect(through.stops.map(\.offset) == [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1])
        #expect(through.stops[0] == gradient.stops[0])
        #expect(through.stops[4] == gradient.stops[1])
        #expect(through.stops[8] == gradient.stops[2])
        #expect(through.stops[1].color == Self.orange.interpolated(inOklabTo: Self.violet, at: 0.25))
        #expect(through.stops[6].color == Self.violet.interpolated(inOklabTo: .white, at: 0.5))
        // At a stop the gradient is the stop, and halfway it is the mix and not the mean in linear light.
        #expect(through.pixel(at: 0.5) == Self.violet.pixel)
        #expect(Tests.close(through.pixel(at: 0.25), Self.orange.interpolated(inOklabTo: Self.violet, at: 0.5).pixel))
        #expect(!Tests.close(through.pixel(at: 0.25), gradient.pixel(at: 0.25), within: 1e-3))
    }

    @Test
    func `A hard edge stays one, and too few steps or stops change nothing`() {
        let edge = Picture.Gradient([
            .init(offset: 0, color: .black), .init(offset: 0.5, color: Self.orange), .init(offset: 0.5, color: Self.violet),
            .init(offset: 0.25, color: .white), .init(offset: 1, color: .white),
        ])
        let through = edge.oklab(steps: 2)
        #expect(through.stops.map(\.offset) == [0, 0.25, 0.5, 0.5, 0.25, 0.75, 1])
        #expect(through.pixel(at: 0.5) == edge.pixel(at: 0.5))
        #expect(edge.oklab(steps: 1) == edge)
        #expect(edge.oklab(steps: 0) == edge)
        let one = Picture.Gradient([.init(offset: 0.5, color: Self.orange)])
        #expect(one.oklab(steps: 8) == one)
        #expect(Picture.Gradient([]).oklab(steps: 8) == Picture.Gradient([]))
    }
}
