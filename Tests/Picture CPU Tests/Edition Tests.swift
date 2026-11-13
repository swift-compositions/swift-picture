import Numeric
import Picture
import Testing

@testable import Picture_CPU

extension `Picture CPU Tests` {
    @Suite
    struct `The edition names the drawing: a picture of each feature draws the pixels recorded at it` {}
}

/// The edition's guard. Each picture below exercises one feature of the renderer on a small raster; the digest of
/// what it draws is recorded beside the edition it was recorded at. A change to drawing changes a digest and fails
/// this test until the edition is raised and the digests recorded again, so a store keyed by the edition never gives
/// back pixels an earlier drawing made. Features not drawn here are not guarded.
extension `Picture CPU Tests`.`The edition names the drawing: a picture of each feature draws the pixels recorded at it` {
    typealias Tests = `Picture CPU Tests`
    typealias Refraction = `Picture CPU Tests`.`A renderer draws glass with a body by the way light takes through it`
    typealias Scenes = `Picture CPU Tests`.`A renderer draws a scene straight onto what is behind, the nearest surface showing`
    typealias Texts = `Picture CPU Tests`.`A renderer never sees a font: text is drawn as its glyphs' paths`

    /// The edition the digests were recorded at.
    static let recorded = 2

    /// The digests of the pictures by name, at `recorded`.
    static let digests: [String: UInt64] = [
        "blur": 16_365_094_295_220_398_297, "body": 1_074_315_639_956_906_798, "fill": 13_478_648_827_929_281_320,
        "glow": 5_255_089_816_006_074_967, "gradient": 7_014_402_895_066_774_693, "image": 17_824_492_936_900_664_916,
        "pane": 8_503_239_913_984_148_697, "scene": 4_145_786_458_600_151_407, "stroke": 1_018_931_843_031_873_205,
        "text": 14_706_559_016_298_247_301,
    ]

    static let backdrop: [Picture.Element] = [
        Tests.fill(Tests.rectangle(-40, -40, 120, 120), Picture.Color(red: 0.1, green: 0.15, blue: 0.2)),
        Tests.fill(Tests.rectangle(18, -40, 4, 120), .white),
        Tests.fill(Tests.rectangle(-40, 12, 120, 3), Picture.Color(red: 0.9, green: 0.6, blue: 0.1)),
    ]

    /// A scene seen square-on through an orthographic camera, into a viewport of 24 × 24.
    static func scene(_ models: [Picture.Scene.Model]) throws -> Picture.Scene {
        let projection = try Projection<Double>.orthographic(width: 4, height: 4, near: 0, far: 10, depth: .unit)
        return Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 24, ury: 24), models: models)
    }

    /// One picture for each feature, drawn on 24 × 24.
    static func pictures() throws -> [String: Picture] {
        let triangle = Tests.polygon([Tests.at(3.3, 4.1), Tests.at(35.7, 9.2), Tests.at(12.4, 33.8)])
        let gradient = Picture.Gradient(evenly: [.white, Picture.Color(red: 0.2, green: 0.4, blue: 0.9), .black])
        let linear = Picture.Paint.linear(.init(from: Tests.at(2, 3), to: Tests.at(37, 31), gradient))
        let pen = Picture.Plane.Path.Stroke(width: 2.5, join: .round, cap: .round)
        let text = try Picture.Text("AV B", font: Texts.font(), size: 14)
        let tile = Raster<Picture.Pixel>(width: 4, height: 4) { x, y in
            Tests.pixel(Float(Int(bitPattern: x)) / 4, Float(Int(bitPattern: y)) / 4, 0.5, 1)
        }
        var image = Picture.Image(tile, placement: Picture.Transform(rows: [[6.5, 1.2, 4], [-0.8, 6.5, 8]]))
        image.sampling = .bilinear
        let shade = Picture.Scene.Material.Shade(ramp: Picture.Gradient(evenly: [.black, .white]), toward: Vector([0.3, 0.5, 1]))
        let shaded = Picture.Scene.Model(.sphere(radius: 1.5, meridians: 12, parallels: 6), transform: Refraction.translation(0, 0, -5), material: .shaded(shade))
        let pane = Picture.Glass.Pane(
            .rectangle(.init(llx: 4, lly: 5, urx: 20, ury: 19), radius: 4),
            glass: Picture.Glass(refraction: .init(index: 1.5, distance: 4)),
            thickness: 4,
            rim: 4
        )
        let ball = Picture.Scene.Model(
            .sphere(radius: 1.5, meridians: 8, parallels: 4),
            transform: Refraction.translation(0, 0, -5),
            material: .glass(.init(bend: 0, refraction: .init(index: 1.5, distance: 8, abbe: 10)))
        )
        return [
            "fill": [Tests.fill(triangle, Tests.translucent), Tests.fill(Tests.rectangle(10.5, 10.25, 17, 9), Tests.blue, rule: .evenodd)],
            "stroke": [.stroke(triangle, .solid(Tests.red), pen: pen)],
            "gradient": [.fill(triangle, linear)],
            "glow": Picture([Tests.fill(Tests.rectangle(14, 14, 12, 12), Tests.red)]).glow(deviation: 3),
            "blur": [.layer(Picture.Layer([Tests.fill(triangle, Tests.blue)], effects: [.blur(.init(deviation: 2))]))],
            "text": [text.placed(.init(.solid(.white)), at: Tests.at(2, 26))],
            "image": [.fill(Tests.rectangle(0, 0, 40, 40), .image(image))],
            "scene": Picture(backdrop + [.scene(try Self.scene([shaded]))]),
            "pane": Picture(backdrop + [.pane(pane)]),
            "body": Picture(backdrop + [.scene(try Self.scene([ball]))]),
        ]
    }

    /// FNV-1a of every component's bits, in row order.
    static func digest(_ raster: Raster<Picture.Pixel>) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for pixel in raster.pixels {
            for component in [pixel.color.red, pixel.color.green, pixel.color.blue, pixel.alpha] {
                var bits = component.bitPattern
                for _ in 0..<4 {
                    hash = (hash ^ UInt64(bits & 0xff)) &* 0x100_0000_01b3
                    bits >>= 8
                }
            }
        }
        return hash
    }

    @Test
    func `Each feature draws the pixels recorded at this edition, on one thread or four`() throws {
        var drawn: [String: UInt64] = [:]
        for (name, picture) in try Self.pictures() {
            var one = Tests.canvas(24, 24)
            try Picture.Renderer.cpu(threads: 1).render(picture, into: &one)
            var four = Tests.canvas(24, 24)
            try Picture.Renderer.cpu(threads: 4).render(picture, into: &four)
            #expect(one == four, "\(name) draws differently on four threads")
            drawn[name] = Self.digest(one)
        }
        let changed = drawn.keys.sorted().filter { drawn[$0] != Self.digests[$0] }
        #expect(
            changed.isEmpty && Picture.Renderer.CPU.edition == Self.recorded,
            """
            drawing changed: raise the edition and record the new digests (\(changed.joined(separator: ", ")); \
            edition \(Picture.Renderer.CPU.edition), recorded at \(Self.recorded)): \
            \(drawn.keys.sorted().map { "\"\($0)\": \(drawn[$0] ?? 0)" }.joined(separator: ", "))
            """
        )
    }
}
