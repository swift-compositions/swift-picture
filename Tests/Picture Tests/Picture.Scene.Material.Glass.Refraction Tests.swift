import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `Glass with a body bends light going in and coming out` {}
}

extension `Picture Tests`.`Glass with a body bends light going in and coming out` {
    typealias Tests = `Picture Tests`
    typealias Glass = Picture.Scene.Material.Glass
    typealias Refraction = Picture.Scene.Material.Glass.Refraction

    static func close(_ a: Vector<3, Double>, _ b: Vector<3, Double>, within tolerance: Double = 1e-12) -> Bool {
        Tests.close(a[0], b[0], within: tolerance) && Tests.close(a[1], b[1], within: tolerance) && Tests.close(a[2], b[2], within: tolerance)
    }

    @Test
    func `Light bends by Snell's law, goes straight on head-on, and keeps unit length`() throws {
        let normal = Vector<3, Double>([0, 0, 1])
        #expect(Refraction.bent(Vector([0, 0, -1]), at: normal, ratio: 1 / 1.5) == Vector([0, 0, -1]))
        let slanted = Vector<3, Double>([0.6, 0, -0.8])
        let inside = try #require(Refraction.bent(slanted, at: normal, ratio: 1 / 1.5))
        #expect(Tests.close(inside[0], 0.6 / 1.5, within: 1e-12))
        #expect(inside[1] == 0)
        #expect(Tests.close(inside[0] * inside[0] + inside[2] * inside[2], 1, within: 1e-12))
        #expect(inside[2] < 0)
        #expect(Refraction.bent(slanted, at: normal, ratio: 1) == slanted)
    }

    @Test
    func `Light leaves through a parallel face in the direction it came, and none leaves beyond the critical angle`() throws {
        let slanted = Vector<3, Double>([0.6, 0, -0.8])
        let inside = try #require(Refraction.bent(slanted, at: Vector([0, 0, 1]), ratio: 1 / 1.5))
        let outside = try #require(Refraction.bent(inside, at: Vector([0, 0, 1]), ratio: 1.5))
        #expect(Self.close(outside, slanted))
        #expect(Refraction.bent(Vector([0.8, 0, -0.6]), at: Vector([0, 0, 1]), ratio: 1.5) == nil)
        #expect(Refraction.bent(Vector([0.66, 0, -(1 - 0.66 * 0.66).squareRoot()]), at: Vector([0, 0, 1]), ratio: 1.5) != nil)
        #expect(Refraction.bent(Vector([0.67, 0, -(1 - 0.67 * 0.67).squareRoot()]), at: Vector([0, 0, 1]), ratio: 1.5) == nil)
    }

    @Test
    func `A surface mirrors a direction about its normal`() {
        #expect(Refraction.mirrored(Vector([0.6, 0, -0.8]), at: Vector([0, 0, 1])) == Vector([0.6, 0, 0.8]))
        #expect(Refraction.mirrored(Vector([0, 0, -1]), at: Vector([0, 0, 1])) == Vector([0, 0, 1]))
        #expect(Refraction.mirrored(Vector([0, 1, 0]), at: Vector([0, 0, 1])) == Vector([0, 1, 0]))
    }

    @Test
    func `The share a surface mirrors is Fresnel's: four hundredths head-on at 1.5, all of it at a grazing angle`() {
        let glass = Refraction(index: 1.5)
        #expect(Tests.close(glass.reflectance(cosine: 1), 0.04, within: 1e-12))
        #expect(Tests.close(glass.reflectance(cosine: 0), 1, within: 1e-12))
        #expect(Tests.close(glass.reflectance(cosine: 0.5), 0.089_186_712_802_212_76, within: 1e-9))
        var last = 0.0
        for step in stride(from: 1.0, through: 0.0, by: -0.05) {
            let share = glass.reflectance(cosine: step)
            #expect(share >= last - 1e-12)
            last = share
        }
        #expect(Tests.close(Refraction(index: 1).reflectance(cosine: 0.3), 0, within: 1e-12))
        #expect(Tests.close(Refraction(index: 2).reflectance(cosine: 1), 1.0 / 9, within: 1e-12))
    }

    @Test
    func `Red is bent least and blue most, and no colour by an index below one`() {
        let glass = Refraction(index: 1.5, dispersion: 0.25)
        #expect(glass.indices[0] == 1.25)
        #expect(glass.indices[1] == 1.5)
        #expect(glass.indices[2] == 1.75)
        let plain = Refraction()
        #expect(plain.index == 1.5 && plain.distance == 1 && plain.dispersion == 0 && plain.surroundings == nil)
        #expect(plain.indices[0] == 1.5 && plain.indices[2] == 1.5)
        let thin = Refraction(index: 1.1, dispersion: 0.3)
        #expect(thin.indices[0] == 1)
        let normal = Vector<3, Double>([0, 0, 1])
        let slanted = Vector<3, Double>([0.6, 0, -0.8])
        let red = Refraction.bent(slanted, at: normal, ratio: 1 / glass.indices[0])
        let blue = Refraction.bent(slanted, at: normal, ratio: 1 / glass.indices[2])
        #expect((red?[0] ?? 0) > (blue?[0] ?? 1))
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
        let lit = Glass(bend: 0, light: light, refraction: .init(surroundings: around))
        #expect(pixel(lit, beyond: 0, by: 0) == Picture.Color(red: 1, green: 0, blue: 0).pixel.composited(over: grey, operator: .lighter, coverage: 1))
        let shaded = lit.shading.pixel(over: reads, through: 1, leaving: normal, beyond: 0.3, mirroring: normal, by: 0.2, facing: normal)
        #expect(shaded == lit.pixel(over: reads, through: 1, leaving: normal, beyond: 0.3, mirroring: normal, by: 0.2, facing: normal))
    }
}
