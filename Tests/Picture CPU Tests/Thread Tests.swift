import Numeric
import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A frame drawn on several threads is the frame drawn on one, bit for bit` {}
}

extension `Picture CPU Tests`.`A frame drawn on several threads is the frame drawn on one, bit for bit` {
    typealias Tests = `Picture CPU Tests`
    typealias Timing = `Picture CPU Tests`.`Timing`

    /// The timing suite's frames at about a seventh of their size, so that every pass is large enough to be shared out.
    static func small(_ picture: Picture) -> Picture.Element {
        .group(.init(picture, transform: .init(rows: [[0.14, 0, 3], [0, 0.14, 2]])))
    }

    /// Every element kind and every kind of effect pass, each effect in a layer of its own: zoom and displacement
    /// are left out, as they are drawn by the same pass as chromatic and pixelation and cost the most in a debug build.
    static func frame() throws -> Picture {
        let flat = Timing.flat
        let effects: [Picture.Effect] = [
            .blur(.init(deviation: 7)),
            .chromatic(.init(red: .init([6, 0]), blue: .init([-6, 0]))),
            .pixelation(.init(width: 24, height: 24)),
            .kaleidoscope(.init(center: Tests.at(960, 540), segments: 6)),
        ]
        var elements: [Picture.Element] = [small(flat)]
        for (index, effect) in effects.enumerated() {
            let layer = Picture.Layer(flat, effects: [effect], opacity: 0.5, blend: index.isMultiple(of: 2) ? .screen : .multiply)
            elements.append(small([.layer(layer)]))
        }
        elements.append(small(flat.glow(deviation: 5)))
        elements.append(small(flat.backdrop([.blur(.init(deviation: 20))], clip: .init(Tests.rectangle(400, 200, 900, 500)))))
        elements.append(small([.sprites(.init(Array(Timing.swarm.sprites.prefix(2000)), profile: .soft))]))
        let glass = Picture.Scene.Material.glass(.init(bend: 40, tint: .init(red: 1, green: 1, blue: 1, alpha: 0.1)))
        elements.append(small([.scene(try torus(.flat(.init(red: 0.9, green: 0.5, blue: 0.3))))]))
        elements.append(small([.scene(try torus(glass))]))
        let around = Picture.Scene.Material.Glass.Surroundings(above: .white, below: .init(gray: 0.2), width: 1.2)
        let body = Picture.Scene.Material.Glass.Refraction(index: 1.5, distance: 2, dispersion: 0.05, surroundings: around)
        elements.append(small([.scene(try torus(.glass(.init(bend: 0, tint: .init(red: 1, green: 0.4, blue: 0.5, alpha: 0.3), refraction: body))))]))
        elements.append(small([.scene(try torus(.wireframe(.init(red: 0.2, green: 0.5, blue: 0.9), width: 1.5)))]))
        return Picture(elements)
    }

    /// The timing suite's torus with fewer quads.
    static func torus(_ material: Picture.Scene.Material) throws -> Picture.Scene {
        let scene = try Timing.torus(material)
        let mesh = Mesh<Point<3, Double>>.torus(major: 2, minor: 0.8, segments: 24, sides: 12)
        return Picture.Scene(
            camera: scene.camera,
            viewport: scene.viewport,
            models: [.init(mesh, transform: scene.models[0].transform, material: material)]
        )
    }

    static func drawn(_ picture: Picture, threads: Cardinal) throws -> Tests.Canvas {
        var raster = Tests.canvas(272, 154, Tests.pixel(0.02, 0.03, 0.05, 1))
        try Picture.Renderer.cpu(threads: threads).render(picture, into: &raster)
        return raster
    }

    @Test
    func `Four and nine threads give the one-thread raster exactly`() throws {
        let picture = try Self.frame()
        let one = try Self.drawn(picture, threads: 1)
        #expect(one.pixels.contains { $0 != one.pixels[0] })
        for threads: Cardinal in [4, 9] {
            #expect(try Self.drawn(picture, threads: threads) == one, "\(threads) threads")
        }
        #expect(try Self.drawn(picture, threads: 0) == one)
    }

    @Test
    func `A fill larger than one part of work reaches every row and column of it`() throws {
        let colour = Picture.Color(red: 0.3, green: 0.6, blue: 0.9)
        for threads: Cardinal in [1, 4] {
            let drawn = try Self.drawn([Tests.fill(Tests.rectangle(0, 0, 272, 154), colour)], threads: threads)
            #expect(drawn.pixels.allSatisfy { $0 == colour.pixel }, "\(threads) threads")
        }
    }
}
