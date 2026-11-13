import Numeric
import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws glass with a body by the way light takes through it` {}
}

extension `Picture CPU Tests`.`A renderer draws glass with a body by the way light takes through it` {
    typealias Tests = `Picture CPU Tests`
    typealias Vertex = Point<3, Double>
    typealias Glass = Picture.Glass

    /// An orthographic camera over x −2…2 and y −2…2 into a viewport of 40 × 40, depth 0 at z 0 and 1 at z −10.
    static func flat(_ models: [Picture.Scene.Model]) throws -> Picture.Scene {
        let projection = try Projection<Double>.orthographic(width: 4, height: 4, near: 0, far: 10, depth: .unit)
        return Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 40, ury: 40), models: models)
    }

    /// A perspective camera, near plane at 1, a window of −1…1 there, into a viewport of 40 × 40.
    static func deep(_ models: [Picture.Scene.Model]) throws -> Picture.Scene {
        let projection = try Projection<Double>(.perspective, left: -1, right: 1, bottom: -1, top: 1, near: 1, far: 20, depth: .symmetric)
        return Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 40, ury: 40), models: models)
    }

    static func translation(_ x: Double, _ y: Double, _ z: Double) -> Matrix<4, 4, Double> {
        Matrix(rows: [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]])
    }

    /// A ball of radius 1.5 five units in front of the eye: fifteen pixels of radius around (20, 20).
    static func ball(_ glass: Glass) -> Picture.Scene.Model {
        Picture.Scene.Model(.sphere(radius: 1.5, meridians: 48, parallels: 24), transform: translation(0, 0, -5), material: .glass(glass))
    }

    /// Two squares of side 3 facing each other across a slab one unit thick, the near one at z −4.
    static func slab(_ glass: Glass) throws -> Picture.Scene.Model {
        let h = 1.5
        let mesh = try Mesh(
            vertices: [
                Vertex([-h, -h, -4]), Vertex([h, -h, -4]), Vertex([h, h, -4]), Vertex([-h, h, -4]),
                Vertex([-h, -h, -5]), Vertex([-h, h, -5]), Vertex([h, h, -5]), Vertex([h, -h, -5]),
            ],
            faces: [Polygon(0, 1, 2, 3), Polygon(4, 5, 6, 7)]
        )
        return Picture.Scene.Model(mesh, material: .glass(glass))
    }

    /// Red on the left half and blue on the right, behind everything.
    static let halves: [Picture.Element] = [
        Tests.fill(Tests.rectangle(-40, -40, 60, 120), Tests.red),
        Tests.fill(Tests.rectangle(20, -40, 60, 120), Tests.blue),
    ]

    static let grey = Tests.pixel(0.5, 0.5, 0.5, 1)

    @Test
    func `Light goes straight through a slab seen head-on, and through any body whose index is one`() throws {
        let gradient = Picture.Paint.linear(
            .init(from: Tests.at(0, 0), to: Tests.at(40, 0), .init([.init(offset: 0, color: Tests.red), .init(offset: 1, color: Tests.blue)]))
        )
        let background: [Picture.Element] = [.shape(.init(Tests.rectangle(-20, -20, 80, 80), fill: .init(gradient)))]
        let plain = try Tests.drawn(Picture(background), on: Tests.canvas(40, 40))
        let slab = try Self.slab(.init(bend: 30, refraction: .init(index: 1.5, distance: 3)))
        #expect(Tests.close(try Tests.drawn(Picture(background + [.scene(try Self.flat([slab]))]), on: Tests.canvas(40, 40)), plain, within: 1e-4))
        // Through a lens that converges, only the line of sight down the middle meets the slab head-on.
        let deep = try Tests.drawn(Picture(background + [.scene(try Self.deep([slab]))]), on: Tests.canvas(40, 40))
        #expect(Tests.close(Tests.at(deep, 19, 19), Tests.at(plain, 19, 19), within: 2e-3))
        #expect(Tests.close(Tests.at(deep, 20, 20), Tests.at(plain, 20, 20), within: 2e-3))
        #expect(!Tests.close(Tests.at(deep, 26, 20), Tests.at(plain, 26, 20), within: 2e-3))
        // A ball's rim covers part of a pixel, whose mean is then not the gradient's at its middle.
        let ball = Self.ball(.init(bend: 30, refraction: .init(index: 1, distance: 3)))
        let through = try Tests.drawn(Picture(background + [.scene(try Self.flat([ball]))]), on: Tests.canvas(40, 40))
        #expect(Tests.close(through, plain, within: 0.02))
        for (x, y): (UInt, UInt) in [(20, 20), (10, 20), (29, 20), (20, 9), (26, 27)] {
            #expect(Tests.close(Tests.at(through, x, y), Tests.at(plain, x, y), within: 1e-4))
        }
        let bent = Self.ball(.init(bend: 30, refraction: .init(index: 1.5, distance: 3)))
        #expect(!Tests.close(try Tests.drawn(Picture(background + [.scene(try Self.flat([bent]))]), on: Tests.canvas(40, 40)), plain, within: 0.02))
    }

    @Test
    func `A ball turns the picture behind it over: what is on the left is seen on the right`() throws {
        let ball = Self.ball(.init(bend: 0, refraction: .init(index: 1.5, distance: 4)))
        let raster = try Tests.drawn(Picture(Self.halves + [.scene(try Self.flat([ball]))]), on: Tests.canvas(40, 40))
        for y: UInt in [16, 20, 24] {
            #expect(Tests.close(Tests.at(raster, 14, y), Tests.blue.pixel, within: 1e-3))
            #expect(Tests.close(Tests.at(raster, 25, y), Tests.red.pixel, within: 1e-3))
        }
        #expect(Tests.at(raster, 2, 20) == Tests.red.pixel)
        #expect(Tests.at(raster, 37, 20) == Tests.blue.pixel)
        let near = Self.ball(.init(bend: 0, refraction: .init(index: 1.5, distance: 0)))
        let upright = try Tests.drawn(Picture(Self.halves + [.scene(try Self.flat([near]))]), on: Tests.canvas(40, 40))
        #expect(Tests.close(Tests.at(upright, 14, 20), Tests.red.pixel, within: 1e-3))
        #expect(Tests.close(Tests.at(upright, 25, 20), Tests.blue.pixel, within: 1e-3))
    }

    @Test
    func `Glass with a body takes the same frost and adaptation as a pane`() throws {
        let stripes: [Picture.Element] = [Tests.fill(Tests.rectangle(-40, -40, 120, 120), .black)]
            + stride(from: -40.0, to: 80, by: 4).map { Tests.fill(Tests.rectangle($0, -40, 2, 120), .white) }
        func drawn(_ glass: Glass) throws -> Tests.Canvas {
            try Tests.drawn(Picture(stripes + [.scene(try Self.flat([Self.ball(glass)]))]), on: Tests.canvas(40, 40))
        }
        let clear = try drawn(.init(refraction: .init(index: 1)))
        let frosted = try drawn(.init(refraction: .init(index: 1), frost: 3))
        let sharp = (17..<23).map { Tests.at(clear, UInt($0), 20).color.red }
        let soft = (17..<23).map { Tests.at(frosted, UInt($0), 20).color.red }
        #expect(sharp.max()! - sharp.min()! > 0.7)
        #expect(soft.max()! - soft.min()! < 0.2)
        let lifted = try drawn(.init(refraction: .init(index: 1), frost: 3, adaptation: .init(toward: .white, strength: 0.5)))
        #expect(Tests.at(lifted, 20, 20).color.red > Tests.at(frosted, 20, 20).color.red)
    }

    @Test
    func `With dispersion a ball fans a white line into colours, and keeps a white backdrop white`() throws {
        let stripes: [Picture.Element] = [
            Tests.fill(Tests.rectangle(-40, -40, 120, 120), .black),
            Tests.fill(Tests.rectangle(18, -40, 4, 120), .white),
        ]
        func drawn(_ abbe: Double, over picture: [Picture.Element]) throws -> Tests.Canvas {
            let ball = Self.ball(.init(bend: 0, refraction: .init(index: 1.5, distance: 4, abbe: abbe)))
            return try Tests.drawn(Picture(picture + [.scene(try Self.flat([ball]))]), on: Tests.canvas(40, 40))
        }
        let one = try drawn(.infinity, over: stripes)
        let split = try drawn(10, over: stripes)
        var apart = false
        for (a, b) in zip(one.pixels, split.pixels) {
            #expect(abs(a.color.red - a.color.green) <= 1e-5 && abs(a.color.blue - a.color.green) <= 1e-5)
            if abs(b.color.red - b.color.blue) > 0.2 { apart = true }
        }
        #expect(apart)
        let white = [Tests.fill(Tests.rectangle(-40, -40, 120, 120), .white)]
        #expect(Tests.close(try drawn(10, over: white), try drawn(.infinity, over: white), within: 2e-5))
    }

    @Test
    func `The tint deepens with the thickness of the body`() throws {
        let tint = Picture.Color(red: 1, green: 0, blue: 0, alpha: 0.3)
        let ball = Self.ball(.init(bend: 0, tint: tint, refraction: .init(index: 1, distance: 1)))
        let raster = try Tests.drawn([Tests.fill(Tests.rectangle(-40, -40, 120, 120), .white), .scene(try Self.flat([ball]))], on: Tests.canvas(40, 40))
        func taken(_ length: Double) -> Picture.Pixel {
            var deep = tint
            deep.alpha = 1 - Float(Double.exp(length * Double.log(0.7)))
            return deep.pixel.composited(over: Picture.Color.white.pixel)
        }
        let aside = 2 * (1.5 * 1.5 - 1.05 * 1.05).squareRoot()
        #expect(Tests.close(Tests.at(raster, 20, 20), taken(3), within: 0.01))
        #expect(Tests.close(Tests.at(raster, 30, 20), taken(aside), within: 0.02))
        #expect(Tests.at(raster, 30, 20).color.green > Tests.at(raster, 20, 20).color.green + 0.05)
        #expect(Tests.at(raster, 2, 2) == Picture.Color.white.pixel)
    }

    @Test
    func `The rim shows the surroundings turned over, as a ball shows everything, and the middle the picture behind`() throws {
        let around = Glass.Surroundings(above: .white, below: .black, width: 1)
        let ball = Self.ball(.init(bend: 0, refraction: .init(index: 1.5, distance: 4, surroundings: around)))
        let background = Tests.fill(Tests.rectangle(-40, -40, 120, 120), Picture.Color(red: 0.5, green: 0.5, blue: 0.5))
        let raster = try Tests.drawn([background, .scene(try Self.flat([ball]))], on: Tests.canvas(40, 40))
        let behind = Picture.Color(red: 0.5, green: 0.5, blue: 0.5).pixel
        let middle = Tests.at(raster, 20, 20)
        #expect(abs(middle.color.green - behind.color.green) < 0.05)
        #expect(Tests.at(raster, 20, 6).color.green < behind.color.green - 0.05)
        #expect(Tests.at(raster, 20, 33).color.green > behind.color.green + 0.2)
        let bare = Self.ball(.init(bend: 0, refraction: .init(index: 1.5, distance: 4)))
        let plain = try Tests.drawn([background, .scene(try Self.flat([bare]))], on: Tests.canvas(40, 40))
        #expect(Tests.close(plain, try Tests.drawn([background], on: Tests.canvas(40, 40)), within: 1e-4))
    }
}
