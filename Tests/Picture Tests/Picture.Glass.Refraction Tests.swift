import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `Glass with a body bends light going in and coming out` {}
}

extension `Picture Tests`.`Glass with a body bends light going in and coming out` {
    typealias Tests = `Picture Tests`
    typealias Glass = Picture.Glass
    typealias Refraction = Picture.Glass.Refraction

    static func close(_ a: Vector<3, Double>, _ b: Vector<3, Double>, within tolerance: Double = 1e-12) -> Bool {
        Tests.close(a[0], b[0], within: tolerance) && Tests.close(a[1], b[1], within: tolerance) && Tests.close(a[2], b[2], within: tolerance)
    }

    @Test
    func `The glass's index is its medium's by Cauchy's law, never below vacuum's`() {
        let glass = Refraction(index: 1.5, abbe: 30)
        #expect(glass.index(at: .d) == 1.5)
        #expect(glass.index(at: .init(nanometres: 420)) > glass.index(at: .init(nanometres: 520)))
        #expect(glass.index(at: .init(nanometres: 520)) > glass.index(at: .init(nanometres: 680)))
        let plain = Refraction()
        #expect(plain.index == 1.5 && plain.distance == 1 && plain.medium.abbe == Refraction.Dispersion.subtle && plain.surroundings == nil)
        let none = Refraction(abbe: Refraction.Dispersion.none)
        #expect(none.index(at: .init(nanometres: 420)) == 1.5 && none.index(at: .init(nanometres: 680)) == 1.5)
        #expect(Refraction(index: 1.01, abbe: 0.01).index(at: .init(nanometres: 700)) == .vacuum)
        #expect(Refraction(index: 0.8).index == .vacuum)
    }

    @Test
    func `A spectrum's weights gather white back to white, and one wavelength is the plain bend`() {
        for count in [2, 3, 5, 7, 12, 32] {
            let spectrum = Picture.Glass.Spectrum(count: count)
            #expect(spectrum.wavelengths.count == count)
            #expect(spectrum.wavelengths == spectrum.wavelengths.sorted())
            let sums = spectrum.weights.reduce((Float(0), Float(0), Float(0))) { ($0.0 + $1.red, $0.1 + $1.green, $0.2 + $1.blue) }
            #expect(Tests.close(sums.0, 1, within: 1e-5) && Tests.close(sums.1, 1, within: 1e-5) && Tests.close(sums.2, 1, within: 1e-5))
            let white = Picture.Color.white.pixel
            #expect(Tests.close(spectrum.gathered(Array(repeating: white, count: count)), white, within: 1e-5))
        }
        let one = Picture.Glass.Spectrum(count: 1)
        #expect(one.wavelengths == [.d])
        #expect(one.weights == [.init(red: 1, green: 1, blue: 1)])
        let seven = Picture.Glass.Spectrum(count: 7)
        #expect(seven.weights[0].blue > seven.weights[0].red)
        #expect(seven.weights[6].red > seven.weights[6].blue)
        #expect(Picture.Glass.Spectrum.count(for: 0) == 1)
        #expect(Picture.Glass.Spectrum.count(for: 10) == 12)
        #expect(Picture.Glass.Spectrum.count(for: 1000) == 32)
    }

    @Test
    func `With dispersion blue's sheen leans further than red's, and without it every colour's is the glass's`() {
        #expect(Refraction(index: 1.5, abbe: .infinity).tilts[0] == 1 && Refraction(index: 1.5, abbe: .infinity).tilts[2] == 1)
        let tilts = Refraction(index: 1.5, abbe: 20).tilts
        #expect(tilts[2] > tilts[1] && tilts[1] > tilts[0])
        #expect(abs(tilts[1] - 1) < 0.03)
        let light = Glass.Light(direction: Vector([0, 1, 1]), gloss: 0, highlight: 0, sheen: 1, sharpness: 4)
        let normal = Vector<3, Double>([0, 0.6, 0.8])
        #expect(light.reflection(for: normal, tilt: 1) == light.reflection(for: normal))
        #expect(light.reflection(for: normal, tilt: 1.2) > light.reflection(for: normal))
    }

    @Test
    func `Surroundings show one colour overhead and one underfoot, half of each at the horizon`() {
        let around = Glass.Surroundings(above: .white, below: .black)
        #expect(around.width == .infinity)
        #expect(Glass.Surroundings.share(toward: Vector([0, 2, 0])) == 1)
        #expect(Glass.Surroundings.share(toward: Vector([0, -1, 0])) == 0)
        #expect(Glass.Surroundings.share(toward: Vector([1, 0, -1])) == 0.5)
        #expect(Glass.Surroundings.share(toward: .zero) == 0.5)
        #expect(Tests.close(Glass.Surroundings.share(toward: Vector([0.8, 0.6, 0])), 0.8 * 0.8 * (3 - 1.6), within: 1e-12))
        #expect(around.pixel(toward: Vector([0, 1, 0])) == Picture.Color.white.pixel)
        #expect(around.pixel(toward: Vector([0, -1, 0])) == Picture.Color.black.pixel)
        #expect(Tests.close(around.pixel(toward: Vector([0, 0, -1])), Tests.pixel(0.5, 0.5, 0.5, 1)))
    }

    @Test
    func `Light that leaves further aside than the picture behind is wide shows the surroundings`() {
        let sight = Vector<3, Double>([0, 0, -1])
        let endless = Glass.Surroundings(above: .white, below: .black)
        #expect(endless.share(leaving: Vector([1, 0, 0]), along: sight) == 0)
        let room = Glass.Surroundings(above: .white, below: .black, width: 1)
        #expect(room.share(leaving: sight, along: sight) == 0)
        let length = (1 + 0.85 * 0.85).squareRoot()
        #expect(Tests.close(room.share(leaving: Vector([0.85 / length, 0, -1 / length]), along: sight), 0.5, within: 1e-9))
        #expect(Tests.close(room.share(leaving: Vector([0.6, 0, -0.8]), along: sight), 2.0 / 27, within: 1e-9))
        #expect(room.share(leaving: Vector([0.5, 0, -0.866_025_403_784_438_6]), along: sight) == 0)
        #expect(room.share(leaving: Vector([0.8, 0, -0.6]), along: sight) == 1)
        #expect(room.share(leaving: Vector([1, 0, 0]), along: sight) == 1)
        #expect(room.share(leaving: Vector([0, 0, 1]), along: sight) == 1)
    }

    @Test
    func `Each colour comes from its own read, and the tint is taken on by the length of the way through`() {
        let reads: InlineArray<3, Picture.Pixel> = [Tests.pixel(0.9, 0.1, 0.1, 1), Tests.pixel(0.2, 0.8, 0.2, 1), Tests.pixel(0.3, 0.3, 0.7, 1)]
        let normal = Vector<3, Double>([0, 0, 1])
        func pixel(_ glass: Glass, through length: Double, beyond: Double = 0, by share: Double = 0) -> Picture.Pixel {
            glass.pixel(over: reads, through: length, leaving: Vector([0, -1, 0]), beyond: beyond, mirroring: Vector([0, 1, 0]), by: share, facing: normal)
        }
        let split = Tests.pixel(0.9, 0.8, 0.7, 1)
        let clear = Glass(bend: 0, refraction: .init())
        #expect(pixel(clear, through: 3) == split)
        let tint = Picture.Color(red: 1, green: 0, blue: 0, alpha: 0.5)
        let rosy = Glass(bend: 0, tint: tint, refraction: .init())
        #expect(pixel(rosy, through: 0) == split)
        #expect(Tests.close(pixel(rosy, through: 1), tint.pixel.composited(over: split)))
        #expect(Tests.close(pixel(rosy, through: 2), Picture.Color(red: 1, green: 0, blue: 0, alpha: 0.75).pixel.composited(over: split)))
        #expect(pixel(Glass(bend: 0, tint: .black, refraction: .init()), through: 0.01) == Tests.pixel(0, 0, 0, 1))
    }

    @Test
    func `Surroundings are mixed in where light misses the picture and where the surface mirrors, and the light is added last`() {
        let grey = Tests.pixel(0.5, 0.5, 0.5, 1)
        let reads: InlineArray<3, Picture.Pixel> = [grey, grey, grey]
        let normal = Vector<3, Double>([0, 0, 1])
        let around = Glass.Surroundings(above: .white, below: .black, width: 1)
        let glass = Glass(bend: 0, refraction: .init(surroundings: around))
        func pixel(_ glass: Glass, beyond: Double, by share: Double) -> Picture.Pixel {
            glass.pixel(over: reads, through: 1, leaving: Vector([0, -1, 0]), beyond: beyond, mirroring: Vector([0, 1, 0]), by: share, facing: normal)
        }
        #expect(pixel(glass, beyond: 0, by: 0) == grey)
        #expect(Tests.close(pixel(glass, beyond: 1, by: 0), Tests.pixel(0, 0, 0, 1)))
        #expect(Tests.close(pixel(glass, beyond: 0.5, by: 0), Tests.pixel(0.25, 0.25, 0.25, 1)))
        #expect(Tests.close(pixel(glass, beyond: 0, by: 1), Tests.pixel(1, 1, 1, 1)))
        #expect(Tests.close(pixel(glass, beyond: 1, by: 0.5), Tests.pixel(0.5, 0.5, 0.5, 1)))
        #expect(pixel(Glass(bend: 0, refraction: .init()), beyond: 1, by: 1) == grey)
        let light = Glass.Light(direction: Vector([0, 0, 1]), color: .init(red: 1, green: 0, blue: 0), gloss: 2, rim: 0)
        let lit = Glass(bend: 0, light: light, refraction: .init(abbe: .infinity, surroundings: around))
        let added = Picture.Color(red: 1, green: 0, blue: 0).pixel.composited(over: grey, operator: .lighter, coverage: 1)
        let alpha = Swift.min(Swift.max(added.alpha, 0), 1)
        let held = Picture.Pixel(color: .init(red: Swift.min(added.color.red, alpha), green: Swift.min(added.color.green, alpha), blue: Swift.min(added.color.blue, alpha)), alpha: alpha)
        #expect(pixel(lit, beyond: 0, by: 0) == held)
        let shaded = lit.shading.pixel(over: reads, through: 1, leaving: normal, beyond: 0.3, mirroring: normal, by: 0.2, facing: normal)
        #expect(shaded == lit.pixel(over: reads, through: 1, leaving: normal, beyond: 0.3, mirroring: normal, by: 0.2, facing: normal))
    }
}

extension `Picture Tests`.`Glass with a body bends light going in and coming out` {
    @Test
    func `A ball enlarges what touches it index over two less index times, and turns it over past its focus`() {
        for index in [1.3, 1.5, 1.7] {
            let touching = Refraction(index: .init(index), distance: 0).enlargement(radius: 15)
            #expect(Tests.close(touching, index / (2 - index), within: 1e-12))
        }
        #expect(Tests.close(Refraction(index: 1.5, distance: 0).enlargement(radius: 2), 3, within: 1e-12))
        let focus = 1.5 * 15 / (2 * 0.5) - 15
        var previous = 0.0
        for distance in stride(from: 0.0, to: focus, by: 0.5) {
            let enlargement = Refraction(index: 1.5, distance: distance).enlargement(radius: 15)
            #expect(enlargement > previous)
            previous = enlargement
        }
        #expect(Refraction(index: 1.5, distance: focus + 1).enlargement(radius: 15) < 0)
        #expect(Refraction(index: 1.5, distance: 40).enlargement(radius: 15) > -1)
        // The law is in units of the picture: a ball twice the size at twice the distance enlarges alike.
        #expect(Tests.close(Refraction(index: 1.5, distance: 6).enlargement(radius: 30), Refraction(index: 1.5, distance: 3).enlargement(radius: 15), within: 1e-12))
        #expect(Refraction(index: 1, distance: 3).enlargement(radius: 15) == 1)
        #expect(Refraction(index: 1.5, distance: 3).enlargement(radius: 0) == 1)
    }
}
