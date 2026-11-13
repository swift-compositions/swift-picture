import Numeric
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A pane is a slab of glass with a rounded rim` {}
}

extension `Picture Tests`.`A pane is a slab of glass with a rounded rim` {
    typealias Tests = `Picture Tests`
    typealias Pane = Picture.Glass.Pane
    typealias Refraction = Picture.Glass.Refraction

    static let box = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 200, ury: 100)

    static func pane(index: Double = 1.5, abbe: Double = .infinity, distance: Double = 0) -> Pane {
        Pane(
            .rectangle(box, radius: 30),
            glass: Picture.Glass(refraction: .init(index: index, distance: distance, abbe: abbe)),
            thickness: 20,
            rim: 25,
            profile: 4
        )
    }

    @Test
    func `The top rises from the boundary to the thickness across the rim, and is level from there`() {
        let pane = Self.pane()
        #expect(pane.height(at: 0) == 0)
        #expect(pane.height(at: -3) == 0)
        #expect(pane.height(at: 25) == 20)
        #expect(pane.height(at: 60) == 20)
        #expect(pane.slope(at: 25) == 0)
        #expect(pane.slope(at: 40) == 0)
        #expect(pane.slope(at: 0) == .infinity)
        var previous = 0.0
        for step in 1..<250 {
            let inward = Double(step) / 10
            let height = pane.height(at: inward)
            #expect(height > previous)
            previous = height
            let rate = (pane.height(at: inward + 1e-6) - pane.height(at: inward - 1e-6)) / 2e-6
            #expect(Tests.close(rate, pane.slope(at: inward), within: 1e-4 * Swift.max(1, rate)))
        }
    }

    @Test
    func `Where the top is level the picture is read where it stands, under any index and dispersion`() {
        let pane = Self.pane(index: 1.7, abbe: 20, distance: 40)
        for (x, y) in [(100.0, 50.0), (60.0, 40.0), (150.0, 70.0)] {
            let passage = pane.passage(at: Tests.at(x, y))
            #expect(passage.normal == Vector([0, 0, 1]))
            for wavelength in [400.0, 550, 700] { #expect(passage.offset(for: pane.glass.refraction!.index(at: wavelength)) == .zero) }
            #expect(passage.length == 20)
        }
    }

    @Test
    func `An index of one bends nothing, even across the rim`() {
        let pane = Self.pane(index: 1, distance: 30)
        for (x, y) in [(3.0, 50.0), (100.0, 2.0), (10.0, 10.0)] {
            let passage = pane.passage(at: Tests.at(x, y))
            #expect(abs(passage.offset[0]) < 1e-9)
            #expect(abs(passage.offset[1]) < 1e-9)
        }
    }

    @Test
    func `Across the rim the picture is read further in, the more the nearer the boundary`() {
        let pane = Self.pane()
        var previous = 0.0
        for x in stride(from: 24.0, through: 1, by: -1) {
            let offset = pane.passage(at: Tests.at(x, 50)).offset
            #expect(offset[0] > previous)
            #expect(abs(offset[1]) < 1e-9)
            previous = offset[0]
        }
        let below = pane.passage(at: Tests.at(100, 97)).offset
        #expect(below[1] < 0)
        #expect(abs(below[0]) < 1e-9)
    }

    @Test
    func `Shorter wavelengths read further in, and the glass's own index reads at the offset`() {
        let pane = Self.pane(abbe: 25, distance: 10)
        let refraction = pane.glass.refraction!
        let passage = pane.passage(at: Tests.at(6, 50))
        #expect(passage.offset(for: refraction.index(at: 680))[0] < passage.offset(for: refraction.index(at: 550))[0])
        #expect(passage.offset(for: refraction.index(at: 550))[0] < passage.offset(for: refraction.index(at: 420))[0])
        #expect(passage.offset(for: refraction.index) == passage.offset)
        let plain = Self.pane(distance: 10).passage(at: Tests.at(6, 50))
        #expect(plain.offset(for: Refraction(index: 1.5, abbe: .infinity).index(at: 420)) == plain.offset)
    }

    @Test
    func `The normal faces the eye where the top is level and leans out across the rim`() {
        let pane = Self.pane()
        #expect(pane.normal(at: Tests.at(100, 50)) == Vector([0, 0, 1]))
        let left = pane.normal(at: Tests.at(5, 50))
        #expect(left[0] < 0 && abs(left[1]) < 1e-12 && left[2] > 0)
        let top = pane.normal(at: Tests.at(100, 5))
        #expect(top[1] > 0 && abs(top[0]) < 1e-12)
        let length = (left[0] * left[0] + left[1] * left[1] + left[2] * left[2]).squareRoot()
        #expect(Tests.close(length, 1, within: 1e-12))
    }

    @Test
    func `A skin without a body reads at the glass's offset of the normal`() {
        let pane = Pane(.rectangle(Self.box, radius: 30), glass: Picture.Glass(bend: 12), thickness: 20, rim: 25)
        let passage = pane.passage(at: Tests.at(5, 50))
        let offset = pane.glass.offset(for: passage.normal)
        #expect(passage.offset == offset)
        #expect(passage.offset(for: 1.9) == offset)
        #expect(passage.length == 0)
    }

    @Test
    func `A shadow is half on the moved boundary and falls evenly from inside to outside`() {
        let shadow = Picture.Glass.Shadow(softness: 10)
        #expect(shadow.share(at: 0) == 0.5)
        var previous = 1.0
        for step in -50...50 {
            let share = shadow.share(at: Double(step))
            #expect(share < previous || share == 0)
            #expect(Tests.close(share + shadow.share(at: -Double(step)), 1, within: 1e-12))
            previous = share
        }
        #expect(Picture.Glass.Shadow(softness: 0).share(at: 0.1) == 0)
        #expect(Picture.Glass.Shadow(softness: 0).share(at: -0.1) == 1)
    }
}

extension `Picture Tests` {
    @Suite
    struct `A glass adapts to its backdrop and lights its rim` {}
}

extension `Picture Tests`.`A glass adapts to its backdrop and lights its rim` {
    typealias Tests = `Picture Tests`

    @Test
    func `Adaptation leaves a backdrop as light as its colour alone and lifts a dark one most`() {
        let toward = Picture.Glass.Adaptation(toward: .white, strength: 0.6)
        #expect(toward.pixel(Picture.Color.white.pixel) == Picture.Color.white.pixel)
        let dark = Picture.Color(red: 0.05, green: 0.05, blue: 0.1).pixel
        let mid = Picture.Color(red: 0.5, green: 0.5, blue: 0.5).pixel
        #expect(toward.share(for: dark) > toward.share(for: mid))
        #expect(Picture.Glass.Adaptation(toward: .white, strength: 0).pixel(dark) == dark)
        let glass = Picture.Glass(tint: .clear, adaptation: toward)
        #expect(glass.pixel(over: dark) == toward.pixel(dark))
        let dim = Picture.Glass.Adaptation(toward: .black, strength: 1)
        #expect(dim.pixel(Picture.Color.white.pixel).color.red < 1e-6)
    }

    @Test
    func `The rim's sheen is brightest on the side toward the light and keeps the counter share on the other`() {
        let light = Picture.Glass.Light(direction: Vector([0, 1, 1]), gloss: 0, sheen: 1, sharpness: 1, counter: 0.25)
        let up = light.reflection(for: Vector([0, 1, 0]))
        let down = light.reflection(for: Vector([0, -1, 0]))
        let aside = light.reflection(for: Vector([1, 0, 0]))
        #expect(Tests.close(up, 1))
        #expect(Tests.close(down, 0.25))
        #expect(Tests.close(aside, 0.25 * 1.25))
        let straight = Picture.Glass.Light(direction: Vector([0, 0, 1]), gloss: 1000, sheen: 1, sharpness: 1)
        #expect(Tests.close(straight.reflection(for: Vector([1, 0, 0])), straight.reflection(for: Vector([0, -1, 0]))))
    }

    @Test
    func `The line along the outline is full to one width in, gone from two and a half, and none outside`() {
        let light = Picture.Glass.Light(direction: Vector([0, 1, 1]), gloss: 0, rim: 0.8, width: 2, counter: 1, focus: 2)
        let up = (x: 0.0, y: 1.0)
        #expect(light.line(at: -0.1, across: up) == 0)
        #expect(Tests.close(light.line(at: 0, across: up), 0.8))
        #expect(Tests.close(light.line(at: 2, across: up), 0.8))
        #expect(light.line(at: 3, across: up) < 0.8 && light.line(at: 3, across: up) > 0)
        #expect(light.line(at: 5, across: up) == 0)
        var previous = 1.0
        for step in 0...60 {
            let value = light.line(at: Double(step) / 10, across: up)
            #expect(value <= previous)
            previous = value
        }
        #expect(Picture.Glass.Light(direction: Vector([0, 1, 1]), rim: 1, width: 0).line(at: 0, across: up) == 0)
        let focused = Picture.Glass.Light(direction: Vector([0, 1, 1]), rim: 1, width: 2, counter: 1, focus: 6)
        #expect(Tests.close(focused.line(at: 1, across: up), 1))
        #expect(Tests.close(focused.line(at: 1, across: (x: 1, y: 0)), 2.0 / 64))
    }

    @Test
    func `Adaptation moves a backdrop's lightness and keeps its hue and chroma`() {
        let toward = Picture.Glass.Adaptation(toward: .white, strength: 0.6)
        let navy = Picture.Color(red: 0.08, green: 0.08, blue: 0.2).pixel
        let before = Picture.Glass.Adaptation.oklab(of: navy)
        let after = Picture.Glass.Adaptation.oklab(of: toward.pixel(navy))
        #expect(after.L > before.L + 0.2)
        #expect(Tests.close(after.a, before.a, within: 2e-3) && Tests.close(after.b, before.b, within: 2e-3))
        let white = Picture.Color.white.pixel
        #expect(Tests.close(Picture.Glass.Adaptation.lightness(of: white), 1, within: 1e-4))
        let back = Picture.Glass.Adaptation.color(L: before.L, a: before.a, b: before.b)
        #expect(Tests.close(back.red, navy.color.red, within: 1e-4) && Tests.close(back.blue, navy.color.blue, within: 1e-4))
    }
}
