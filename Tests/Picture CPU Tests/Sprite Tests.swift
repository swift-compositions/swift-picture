import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer adds the sprites' light to what is behind with lighter` {}
}

extension `Picture CPU Tests`.`A renderer adds the sprites' light to what is behind with lighter` {
    typealias Tests = `Picture CPU Tests`

    /// Sprites spread over a raster of 100 × 70 by a fixed rule, of every size from a pixel to most of it.
    static func swarm(_ count: Int, profile: Picture.Sprites.Profile) -> Picture.Sprites {
        let sprites = (0..<count).map { index in
            let x = Double((index * 37) % 113) - 6.5
            let y = Double((index * 53) % 83) - 6.25
            let radius = Double(1 + (index * 7) % 23) * (index.isMultiple(of: 17) ? 3 : 0.5)
            let color = Picture.Color(red: Float(index % 5) / 4, green: Float(index % 3) / 2, blue: 1, alpha: Float(1 + index % 4) / 4)
            return Picture.Sprites.Sprite(center: Tests.at(x, y), radius: radius, color: color)
        }
        return Picture.Sprites(sprites, profile: profile)
    }

    @Test
    func `Each pixel takes the light all sprites add at its centre, with lighter`() throws {
        let backdrop = Tests.pixel(0.1, 0.2, 0.3, 0.5)
        for profile in Picture.Sprites.Profile.allCases {
            let sprites = Self.swarm(300, profile: profile)
            let raster = try Tests.drawn([.sprites(sprites)], on: Tests.canvas(100, 70, backdrop))
            for (x, y) in Tests.positions(100, 70) {
                let light = sprites.light(at: Tests.at(Double(x) + 0.5, Double(y) + 0.5))
                #expect(Tests.at(raster, x, y) == Picture.Sprites.composited(light, over: backdrop))
            }
        }
    }

    @Test
    func `Sprites on an opaque raster leave it opaque however much light they add`() throws {
        let sprites = Self.swarm(300, profile: .hard)
        let raster = try Tests.drawn([.sprites(sprites)], on: Tests.canvas(100, 70, Tests.pixel(0.1, 0.2, 0.3, 1)))
        #expect(raster.pixels.allSatisfy { $0.alpha == 1 })
        #expect(raster.pixels.contains { $0.color.red > 1 || $0.color.green > 1 || $0.color.blue > 1 })
        let sheet = try Tests.drawn([.layer(.init([.sprites(sprites)]))], on: Tests.canvas(100, 70, Tests.pixel(1, 1, 1, 1)))
        #expect(sheet.pixels.allSatisfy { $0.alpha == 1 && $0.color.red >= 0 && $0.color.green >= 0 && $0.color.blue >= 0 })
    }

    @Test
    func `Sprites move with their group, and their order does not matter up to rounding`() throws {
        let sprites = Self.swarm(80, profile: .soft)
        let turn = Picture.Transform(rows: [[0.6, -0.8, 30], [0.8, 0.6, 10]])
        let raster = try Tests.drawn([.group(.init([.sprites(sprites)], transform: turn))], on: Tests.canvas(100, 70))
        let inverse = try turn.inverted()
        for (x, y) in Tests.positions(100, 70) where x.isMultiple(of: 3) && y.isMultiple(of: 7) {
            let moved = inverse.applied(to: Vector([Double(x) + 0.5, Double(y) + 0.5]))
            #expect(Tests.close(Tests.at(raster, x, y), Picture.Sprites.composited(sprites.light(at: Tests.at(moved[0], moved[1])), over: .transparent)))
        }
        let reversed = Picture.Sprites(sprites.sprites.reversed(), profile: .soft)
        let other = try Tests.drawn([.group(.init([.sprites(reversed)], transform: turn))], on: Tests.canvas(100, 70))
        #expect(Tests.close(raster, other))
    }

    @Test
    func `A sprite with no radius gives no light`() throws {
        let backdrop = Tests.canvas(5, 5, Tests.blue.pixel)
        let none = Picture.Sprites([.init(center: Tests.at(2.5, 2.5), radius: 0, color: .white)])
        #expect(try Tests.drawn([.sprites(none)], on: backdrop) == backdrop)
    }
}
