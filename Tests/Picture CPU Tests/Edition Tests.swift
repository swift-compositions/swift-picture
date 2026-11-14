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
    static let recorded = 3

    /// The digests of the pictures by name, at `recorded`.
    static let digests: [String: UInt64] = [
        "blur": 16_365_094_295_220_398_297, "blur wide": 12_362_251_832_773_303_258, "body": 3_847_318_856_642_325_986,
        "chromatic": 7_601_239_310_432_139_073, "clip": 9_197_774_706_600_063_139, "displacement": 40_796_383_757_729_642,
        "fill": 13_478_648_827_929_281_320, "glass lit": 9_817_917_969_293_578_935, "glass skin": 8_928_723_873_393_366_213,
        "glow": 5_255_089_816_006_074_967, "gradient": 13_618_457_707_398_550_439, "grain": 6_616_373_746_132_311_705,
        "haze": 10_324_524_493_056_251_966, "image": 17_824_492_936_900_664_916, "kaleidoscope": 7_307_888_135_593_406_063,
        "kaleidoscope seam": 5_065_068_606_888_849_130, "layer": 6_504_368_761_510_991_401, "pane": 9_473_366_021_337_320_083,
        "pane in layer": 271_991_238_777_680_137, "pane lit": 16_691_523_307_178_275_876,
        "perspective": 8_970_295_728_383_599_765, "pixelation": 15_401_056_594_709_881_789, "points": 14_772_059_698_445_711_661,
        "radial": 5_047_031_188_845_464_965, "scene": 5_599_095_896_402_402_077, "sprites": 16_374_441_649_486_050_100,
        "sprites hard": 17_357_968_471_778_099_155, "stroke": 1_018_931_843_031_873_205, "swirl": 134_901_429_789_531_203,
        "text": 14_706_559_016_298_247_301, "threshold": 15_865_724_926_579_864_926, "wireframe": 10_926_154_388_830_778_519,
        "zoom": 10_111_084_808_051_290_672, "zoom whole": 4_485_286_846_554_271_379,
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
        return try [
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
        ].merging(Self.more(triangle), uniquingKeysWith: { first, _ in first })
    }

    /// One picture for each feature the first pictures do not reach, drawn on 24 × 24.
    static func more(_ triangle: Picture.Plane.Path) throws -> [String: Picture] {
        let content: Picture = [
            Tests.fill(triangle, Tests.blue),
            Tests.fill(Tests.rectangle(2, 9, 20, 3), Picture.Color(red: 0.95, green: 0.8, blue: 0.2)),
            Tests.fill(Tests.rectangle(15, 2, 2, 20), Tests.translucent),
        ]
        func under(_ effect: Picture.Effect) -> Picture {
            [.layer(Picture.Layer(content, effects: [effect]))]
        }
        let centre = Tests.at(12, 12)
        let swarm = (0..<24).map { (index: Int) -> Picture.Sprites.Sprite in
            let x: Double = Double((index * 7) % 23) + 0.3
            let y: Double = Double((index * 11) % 23) + 0.6
            let green: Float = Float(index % 4) / 3
            return Picture.Sprites.Sprite(center: Tests.at(x, y), radius: 1.5 + Double(index % 5), color: Picture.Color(red: 1, green: green, blue: 0.3, alpha: 0.6))
        }
        let sprites = Picture.Sprites(swarm, profile: .soft)
        let hard = Picture.Sprites(sprites.sprites, profile: .hard)
        let torus = Mesh<Point<3, Double>>.torus(major: 1.2, minor: 0.5, segments: 12, sides: 6)
        let turn = Matrix<4, 4, Double>(rows: [[1, 0, 0, 0], [0, 0.6, -0.8, 0], [0, 0.8, 0.6, -5], [0, 0, 0, 1]])
        let color = Picture.Color(red: 0.9, green: 0.5, blue: 0.3)
        let light = Picture.Glass.Light(direction: Vector([-0.4, -0.6, 1]), rim: 0.6, width: 1, sheen: 0.4)
        let shadow = Picture.Glass.Shadow(softness: 2, x: 1, y: 2)
        let lit = Picture.Glass(
            tint: .init(red: 0.9, green: 0.95, blue: 1, alpha: 0.2),
            light: light,
            refraction: .init(index: 1.5, distance: 6, abbe: 10, surroundings: .init(above: .white, below: .black, width: 0.5)),
            frost: 0.6,
            gain: 1.1,
            saturation: 1.2,
            adaptation: .init(toward: .white, strength: 0.4),
            shadows: [shadow]
        )
        let skin = Picture.Glass(bend: 3, tint: .init(red: 1, green: 1, blue: 1, alpha: 0.1), light: light, frost: 0.8, shadows: [shadow])
        var perspective = Picture.Image(
            Raster<Picture.Pixel>(width: 4, height: 4) { x, y in
                Tests.pixel(Float(Int(bitPattern: x)) / 4, 0.3, Float(Int(bitPattern: y)) / 4, 1)
            },
            placement: Matrix<3, 3, Double>(rows: [[5, 0.5, 2], [0.4, 4, 3], [0.02, 0.03, 1]])
        )
        perspective.sampling = .bilinear
        let pane = Picture.Glass.Pane(.capsule(.init(llx: 3, lly: 6, urx: 21, ury: 18)), glass: lit, thickness: 3, rim: 4)
        let radial = Picture.Paint.radial(.init(center: Tests.at(10, 13), radius: 11, Picture.Gradient(evenly: [.white, Tests.red, .clear])))
        return [
            "sprites": [.sprites(sprites)],
            "sprites hard": [.group(.init([.sprites(hard)], transform: .init(rows: [[0.9, 0.3, 1], [-0.3, 0.9, 4]])))],
            "wireframe": [.scene(try Self.scene([.init(torus, transform: turn, material: .wireframe(color, width: 0.08))]))],
            "points": [.scene(try Self.scene([.init(torus, transform: turn, material: .points(color, radius: 0.1))]))],
            "haze": [
                .scene(
                    Picture.Scene(
                        camera: try Self.scene([]).camera,
                        viewport: .init(llx: 0, lly: 0, urx: 24, ury: 24),
                        models: [.init(torus, transform: turn, material: .flat(color))],
                        haze: .init(Picture.Color(red: 0.6, green: 0.7, blue: 0.8), density: 0.2)
                    )
                )
            ],
            "glass lit": Picture(backdrop + [.scene(try Self.scene([.init(torus, transform: turn, material: .glass(lit))]))]),
            "glass skin": Picture(backdrop + [.scene(try Self.scene([.init(torus, transform: turn, material: .glass(skin))]))]),
            "pane lit": Picture(backdrop + [.pane(pane)]),
            "pane in layer": Picture(backdrop + [.layer(Picture.Layer([.pane(pane)], opacity: 0.7))]),
            "radial": [.fill(Tests.rectangle(0, 0, 24, 24), radial)],
            "perspective": [.fill(Tests.rectangle(0, 0, 24, 24), .image(perspective))],
            "clip": [
                .group(.init([Tests.fill(Tests.rectangle(0, 0, 24, 24), Tests.red), .sprites(sprites)], clip: .init(triangle)))
            ],
            "layer": Picture(
                backdrop + [.layer(Picture.Layer(content, opacity: 0.6, blend: .multiply)), .layer(Picture.Layer(content, opacity: 0.5, operator: .lighter))]
            ),
            "zoom": under(.zoom(.init(center: centre, amount: 0.4))),
            "zoom whole": under(.zoom(.init(center: centre, amount: 1))),
            "chromatic": under(.chromatic(.init(red: .init([1.5, 0.5]), blue: .init([-1, 0])))),
            "pixelation": under(.pixelation(.init(width: 3, height: 4))),
            "kaleidoscope": under(.kaleidoscope(.init(center: centre, segments: 5, rotation: .init(0.3)))),
            "kaleidoscope seam": under(
                .kaleidoscope(.init(center: centre, segments: 3, seam: .init(.white, width: 0.5), spokes: Picture.Color(red: 0, green: 0, blue: 0, alpha: 0.5)))
            ),
            "displacement": under(.displacement(.init(seed: .init(1, 2), frequency: 0.2, amplitude: 2))),
            "swirl": under(.swirl(.init(center: centre, radius: 10, angle: 1.2))),
            "grain": under(.grain(.init(seed: .init(3, 4), amount: 0.3, size: 1.5))),
            "threshold": under(.threshold(.init(level: 0.3, knee: 0.2))),
            "blur wide": under(.blur(.init(deviation: 3))),
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
