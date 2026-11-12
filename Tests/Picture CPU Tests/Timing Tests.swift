import Numeric
import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    /// Frame times at 1920 × 1080, measured in release builds only: `swift test -c release --filter Timing`.
    @Suite
    struct `Timing` {}
}

extension `Picture CPU Tests`.`Timing` {
    typealias Tests = `Picture CPU Tests`

    static func disc(_ x: Double, _ y: Double, _ radius: Double) -> Picture.Plane.Path {
        let corners = (0..<128).map { step in
            let angle = Double(step) / 128 * 2 * Double.pi
            return Tests.at(x + radius * Double.cos(angle), y + radius * Double.sin(angle))
        }
        return Tests.polygon(corners)
    }

    /// A full-frame gradient, 40 discs, a clipped group of 20 turned bars and a multiplying layer.
    static var flat: Picture {
        let sky = Picture.Gradient([
            .init(offset: 0, color: .init(red: 0.95, green: 0.55, blue: 0.4)),
            .init(offset: 1, color: .init(red: 0.2, green: 0.1, blue: 0.35)),
        ])
        var elements: [Picture.Element] = [
            .shape(.init(Tests.rectangle(0, 0, 1920, 1080), fill: .init(.linear(.init(from: Tests.at(0, 0), to: Tests.at(400, 1080), sky)))))
        ]
        elements += (0..<40).map { index in
            let x = Double(index % 8) * 240 + 120
            let y = Double(index / 8) * 216 + 108
            let color = Picture.Color(red: Float(index % 3) / 2, green: 0.6, blue: Float(index % 5) / 4, alpha: 0.7)
            let paint: Picture.Paint =
                index.isMultiple(of: 2)
                ? .solid(color)
                : .radial(.init(center: Tests.at(x, y), radius: 100, .init([.init(offset: 0, color: .white), .init(offset: 1, color: color)])))
            return Picture.Element.shape(.init(disc(x, y, 60 + Double(index % 4) * 30), fill: .init(paint)))
        }
        let bars: Picture = Picture(
            (0..<20).map { index in
                .group(
                    .init(
                        [Tests.fill(Tests.rectangle(-300, -12, 600, 24), .init(red: 1, green: 1, blue: 1, alpha: 0.5))],
                        transform: .init(rows: [[0.9, -0.43, 960 + Double(index) * 20], [0.43, 0.9, 300 + Double(index) * 25]])
                    )
                )
            }
        )
        elements.append(.group(.init(bars, clip: .init(disc(960, 540, 420)))))
        elements.append(
            .layer(.init([Tests.fill(Tests.rectangle(200, 600, 1500, 300), .init(red: 0.3, green: 0.8, blue: 0.9))], opacity: 0.8, blend: .multiply))
        )
        return Picture(elements)
    }

    /// 20 000 soft sprites of radius 2 to 20 spread over the frame by a fixed rule.
    static var swarm: Picture.Sprites {
        let sprites = (0..<20_000).map { (index: Int) -> Picture.Sprites.Sprite in
            let x = Double((index * 7919) % 1920)
            let y = Double((index * 104_729) % 1080)
            let color = Picture.Color(red: 1, green: Float(index % 7) / 6, blue: 0.4, alpha: 0.3)
            return Picture.Sprites.Sprite(center: Tests.at(x, y), radius: Double(2 + index % 19), color: color)
        }
        return Picture.Sprites(sprites, profile: .soft)
    }

    /// A torus of 96 × 48 quads, turned toward the camera, filling most of a full-HD viewport.
    static func torus(_ material: Picture.Scene.Material) throws -> Picture.Scene {
        let projection = try Projection<Double>.perspective(fieldOfView: .init(0.9), aspect: 1920.0 / 1080, near: 0.5, far: 50, depth: .symmetric)
        let turn = Matrix<4, 4, Double>(rows: [[1, 0, 0, 0], [0, 0.6, -0.8, 0], [0, 0.8, 0.6, -6], [0, 0, 0, 1]])
        let mesh = Mesh<Point<3, Double>>.torus(major: 2, minor: 0.8, segments: 96, sides: 48)
        return Picture.Scene(
            camera: .init(projection: projection),
            viewport: .init(llx: 0, lly: 0, urx: 1920, ury: 1080),
            models: [.init(mesh, transform: turn, material: material)]
        )
    }

    static func time(_ picture: Picture) throws -> Duration {
        var best = Duration.seconds(1000)
        for _ in 0..<3 {
            var raster = Tests.canvas(1920, 1080, .transparent)
            let clock = ContinuousClock()
            let start = clock.now
            try Tests.renderer.render(picture, into: &raster)
            best = min(best, clock.now - start)
        }
        return best
    }

    #if !DEBUG
        @Test
        func `A flat frame of fills, a clip and a layer`() throws {
            print("Timing: flat frame \(try Self.time(Self.flat))")
            let all = Self.flat.elements
            print("Timing: solid full frame \(try Self.time([Tests.fill(Tests.rectangle(0, 0, 1920, 1080), .white)]))")
            print("Timing: gradient full frame \(try Self.time([all[0]]))")
            print("Timing: 40 discs \(try Self.time(Picture(Array(all[1...40]))))")
            print("Timing: clipped bars \(try Self.time([all[41]]))")
            print("Timing: layer \(try Self.time([all[42]]))")
        }

        @Test
        func `The flat frame under each effect`() throws {
            let effects: [(String, Picture.Effect)] = [
                ("blur 8", .blur(.init(deviation: 8))),
                ("blur 32", .blur(.init(deviation: 32))),
                ("zoom 0.2", .zoom(.init(center: Tests.at(960, 540), amount: 0.2))),
                ("chromatic", .chromatic(.init(red: .init([6, 0]), blue: .init([-6, 0])))),
                ("pixelation", .pixelation(.init(width: 24, height: 24))),
                ("kaleidoscope", .kaleidoscope(.init(center: Tests.at(960, 540), segments: 6))),
                ("displacement", .displacement(.init(seed: .init(1, 2), frequency: 0.01, amplitude: 20))),
            ]
            for (name, effect) in effects {
                print("Timing: flat frame under \(name) \(try Self.time([.layer(.init(Self.flat, effects: [effect]))]))")
            }
            print("Timing: flat frame with a glow of 8 \(try Self.time(Self.flat.glow(deviation: 8)))")
        }

        @Test
        func `Sprites and scenes`() throws {
            print("Timing: 20000 soft sprites \(try Self.time([.sprites(Self.swarm)]))")
            let color = Picture.Color(red: 0.9, green: 0.5, blue: 0.3)
            print("Timing: flat torus \(try Self.time([.scene(try Self.torus(.flat(color)))]))")
            print("Timing: wireframe torus \(try Self.time([.scene(try Self.torus(.wireframe(color, width: 1.5)))]))")
            print("Timing: points torus \(try Self.time([.scene(try Self.torus(.points(color, radius: 2)))]))")
            let glass = Picture.Scene.Material.glass(.init(bend: 40, tint: .init(red: 1, green: 1, blue: 1, alpha: 0.1)))
            print("Timing: glass torus over the flat frame \(try Self.time(Self.flat.appending([.scene(try Self.torus(glass))])))")
        }
    #endif
}
