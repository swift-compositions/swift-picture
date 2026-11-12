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
    #endif
}
