import Numeric
import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws a pane through its glass` {}
}

extension `Picture CPU Tests`.`A renderer draws a pane through its glass` {
    typealias Tests = `Picture CPU Tests`

    static let region = Picture.Plane.Region.rectangle(.init(llx: 10, lly: 10, urx: 70, ury: 50), radius: 12)

    static func pane(_ glass: Picture.Glass, shadow: Picture.Glass.Shadow? = nil) -> Picture.Element {
        var glass = glass
        glass.shadows = shadow.map { [$0] } ?? []
        return .pane(Picture.Glass.Pane(region, glass: glass, thickness: 8, rim: 10))
    }

    /// Black and white stripes four pixels wide.
    static let stripes: [Picture.Element] = [Tests.fill(Tests.rectangle(0, 0, 80, 60), .black)]
        + stride(from: 0.0, to: 80, by: 8).map { Tests.fill(Tests.rectangle($0, 0, 4, 60), .white) }

    @Test
    func `A pane over a flat colour gives that colour under its tint`() throws {
        let colour = Picture.Color(red: 0.2, green: 0.6, blue: 0.9)
        let tint = Picture.Color(red: 1, green: 1, blue: 1, alpha: 0.25)
        let glass = Picture.Glass(tint: tint, refraction: .init(index: 1.6, distance: 5, abbe: 20), frost: 6)
        let raster = try Tests.drawn([Tests.fill(Tests.rectangle(-100, -100, 300, 300), colour), Self.pane(glass)], on: Tests.canvas(80, 60))
        let expected = tint.pixel.composited(over: colour.pixel)
        for (x, y) in Tests.positions(80, 60) {
            let inside = Self.region.distance(to: Tests.at(Double(x) + 0.5, Double(y) + 0.5)) < -1
            let outside = Self.region.distance(to: Tests.at(Double(x) + 0.5, Double(y) + 0.5)) > 1
            if inside { #expect(Tests.close(Tests.at(raster, x, y), expected, within: 2e-4)) }
            if outside { #expect(Tests.at(raster, x, y) == colour.pixel) }
        }
    }

    @Test
    func `A clear pane of index one shows the picture as it is, and leaves the outside alone`() throws {
        let plain = try Tests.drawn(Picture(Self.stripes), on: Tests.canvas(80, 60))
        let through = try Tests.drawn(Picture(Self.stripes + [Self.pane(Picture.Glass(refraction: .init(index: 1)))]), on: Tests.canvas(80, 60))
        // Pixels on the boundary and in the outer rim are the mean of points read between pixel centres.
        for (x, y) in Tests.positions(80, 60) {
            let distance = Self.region.distance(to: Tests.at(Double(x) + 0.5, Double(y) + 0.5))
            guard distance > 1.5 || distance < -5.5 else { continue }
            #expect(Tests.close(Tests.at(through, x, y), Tests.at(plain, x, y), within: 1e-5))
        }
    }

    @Test
    func `The rim lenses the picture while the level middle shows it in place`() throws {
        let plain = try Tests.drawn(Picture(Self.stripes), on: Tests.canvas(80, 60))
        let through = try Tests.drawn(Picture(Self.stripes + [Self.pane(Picture.Glass(refraction: .init(index: 1.5, distance: 10)))]), on: Tests.canvas(80, 60))
        for x: UInt in 30..<50 { #expect(Tests.close(Tests.at(through, x, 30), Tests.at(plain, x, 30), within: 1e-5)) }
        var changed = false
        for x: UInt in 11..<18 where !Tests.close(Tests.at(through, x, 30), Tests.at(plain, x, 30), within: 1e-2) { changed = true }
        #expect(changed)
    }

    @Test
    func `A shadow darkens around the pane and the pane shows the picture without it`() throws {
        let white = Picture.Color.white
        let shadow = Picture.Glass.Shadow(color: Picture.Color(red: 0, green: 0, blue: 0, alpha: 0.5), softness: 4, x: 0, y: 4)
        let raster = try Tests.drawn(
            [Tests.fill(Tests.rectangle(-100, -100, 300, 300), white), Self.pane(Picture.Glass(refraction: .init()), shadow: shadow)],
            on: Tests.canvas(80, 60)
        )
        #expect(Tests.at(raster, 40, 53).color.red < 0.9)
        #expect(Tests.close(Tests.at(raster, 40, 30), white.pixel, within: 1e-5))
        #expect(Tests.at(raster, 40, 2) == white.pixel || Tests.at(raster, 40, 2).color.red > 0.99)
    }

    @Test
    func `Drawing a pane is the same twice and on any number of threads`() throws {
        let glass = Picture.Glass(
            tint: Picture.Color(red: 0.9, green: 0.95, blue: 1, alpha: 0.1),
            light: .init(direction: Vector([-0.3, 0.9, 0.4]), rim: 0.8),
            refraction: .init(index: 1.5, distance: 6, abbe: 25),
            frost: 7,
            adaptation: .init(toward: .white, strength: 0.4)
        )
        let picture = Picture(Self.stripes + [Self.pane(glass, shadow: .init())])
        let once = try Tests.drawn(picture, on: Tests.canvas(80, 60))
        #expect(try Tests.drawn(picture, on: Tests.canvas(80, 60)) == once)
        for threads: Cardinal in [1, 3, 8] {
            var raster = Tests.canvas(80, 60)
            try Picture.Renderer.cpu(threads: threads).render(picture: picture, raster: &raster)
            #expect(raster == once)
        }
    }

    @Test
    func `Frost blurs what a pane shows`() throws {
        let clear = try Tests.drawn(Picture(Self.stripes + [Self.pane(Picture.Glass(refraction: .init(index: 1)))]), on: Tests.canvas(80, 60))
        let frosted = try Tests.drawn(Picture(Self.stripes + [Self.pane(Picture.Glass(refraction: .init(index: 1), frost: 4))]), on: Tests.canvas(80, 60))
        let spread = (36..<44).map { Tests.at(frosted, UInt($0), 30).color.red }
        let sharp = (36..<44).map { Tests.at(clear, UInt($0), 30).color.red }
        #expect((spread.max()! - spread.min()!) < 0.2)
        #expect((sharp.max()! - sharp.min()!) > 0.9)
    }

    @Test
    func `Two panes that come close join by a neck that follows their distance`() throws {
        func drawn(_ gap: Double) throws -> Tests.Canvas {
            let a = Picture.Plane.Region.ball(.init(center: Tests.at(40 - 10 - gap / 2, 30), radius: .init(10)))
            let b = Picture.Plane.Region.ball(.init(center: Tests.at(40 + 10 + gap / 2, 30), radius: .init(10)))
            let glass = Picture.Glass(tint: Picture.Color(red: 1, green: 0, blue: 0, alpha: 1), refraction: .init(index: 1))
            let pane = Picture.Glass.Pane(.union([a, b], radius: 12), glass: glass, thickness: 4, rim: 4)
            return try Tests.drawn([Tests.fill(Tests.rectangle(0, 0, 80, 60), .white), .pane(pane)], on: Tests.canvas(80, 60))
        }
        #expect(Tests.at(try drawn(20), 40, 30) == Picture.Color.white.pixel)
        #expect(Tests.close(Tests.at(try drawn(2), 40, 30), Tests.red.pixel, within: 1e-4))
    }

    @Test
    func `Dispersion fans a white line behind the rim into colours, keeps white white and changes nothing without it`() throws {
        let line: [Picture.Element] = [Tests.fill(Tests.rectangle(0, 0, 80, 60), .black), Tests.fill(Tests.rectangle(20, 0, 2, 60), .white)]
        func drawn(_ abbe: Double, over picture: [Picture.Element]) throws -> Tests.Canvas {
            try Tests.drawn(Picture(picture + [Self.pane(Picture.Glass(refraction: .init(index: 1.5, distance: 12, abbe: abbe)))]), on: Tests.canvas(80, 60))
        }
        let fanned = try drawn(12, over: line)
        let most = fanned.pixels.map { abs($0.color.red - $0.color.blue) }.max() ?? 0
        #expect(most > 0.15)
        let plain = try drawn(.infinity, over: line)
        for pixel in plain.pixels { #expect(abs(pixel.color.red - pixel.color.blue) < 1e-5) }
        let white = [Tests.fill(Tests.rectangle(-100, -100, 300, 300), .white)]
        #expect(Tests.close(try drawn(12, over: white), try drawn(.infinity, over: white), within: 2e-5))
        #expect(Tests.close(try drawn(1e12, over: line), plain, within: 1e-4))
    }

    @Test
    func `The light's line brightens a band along the boundary, brightest on the side toward the light`() throws {
        let black = [Tests.fill(Tests.rectangle(-100, -100, 300, 300), .black)]
        let plain = Picture.Glass(refraction: .init(index: 1))
        var lit = plain
        lit.light = Picture.Glass.Light(direction: Vector([0, 1, 0.2]), gloss: 0, highlight: 0, rim: 1, width: 1.5, counter: 0.5, focus: 2)
        let dark = try Tests.drawn(Picture(black + [Self.pane(plain)]), on: Tests.canvas(80, 60))
        let bright = try Tests.drawn(Picture(black + [Self.pane(lit)]), on: Tests.canvas(80, 60))
        // The top edge is at y 10, the bottom at y 50; picture space's y runs down, so up on the screen is the top.
        #expect(Tests.at(bright, 40, 10).color.red > 0.6)
        #expect(Tests.at(bright, 40, 49).color.red > 0.2)
        #expect(Tests.at(bright, 40, 10).color.red > Tests.at(bright, 40, 49).color.red)
        #expect(Tests.at(dark, 40, 10).color.red < 1e-6)
        #expect(Tests.close(Tests.at(bright, 40, 30), Tests.at(dark, 40, 30), within: 1e-6))
    }
}
