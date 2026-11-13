import Numeric
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A kaleidoscope of n mirrors is symmetric under them, with seams on them and spokes between` {}
}

extension `Picture Tests`.`A kaleidoscope of n mirrors is symmetric under them, with seams on them and spokes between` {
    typealias Tests = `Picture Tests`
    typealias Kaleidoscope = Picture.Effect.Kaleidoscope

    static let center = Tests.at(31, -12)

    /// Points spread around the centre at many distances and angles, none on a mirror edge.
    static let points: [Picture.Plane.Point<2>] = (1...60).map { step in
        let angle = Double(step) * 0.7193
        let radius = 0.37 * Double(step)
        return Tests.at(center[0] + radius * Double.cos(angle), center[1] + radius * Double.sin(angle))
    }

    /// A point turned about the centre.
    static func turned(_ point: Picture.Plane.Point<2>, by angle: Double) -> Picture.Plane.Point<2> {
        let (x, y) = (point[0] - center[0], point[1] - center[1])
        return Tests.at(center[0] + x * Double.cos(angle) - y * Double.sin(angle), center[1] + x * Double.sin(angle) + y * Double.cos(angle))
    }

    /// A point mirrored in the line through the centre at an angle.
    static func mirrored(_ point: Picture.Plane.Point<2>, in angle: Double) -> Picture.Plane.Point<2> {
        let (x, y) = (point[0] - center[0], point[1] - center[1])
        let (c, s) = (Double.cos(2 * angle), Double.sin(2 * angle))
        return Tests.at(center[0] + x * c + y * s, center[1] + x * s - y * c)
    }

    @Test
    func `It reads the same point after a turn by one sector and after a reflection in any mirror`() {
        for count in [1, 2, 3, 5, 6, 8, 12] {
            let kaleidoscope = Kaleidoscope(center: Self.center, segments: Cardinal(UInt(count)), rotation: Radian(0.4))
            let sector = 2 * Double.pi / Double(count)
            for point in Self.points {
                let source = kaleidoscope.source(of: point)
                #expect(Tests.close(kaleidoscope.source(of: Self.turned(point, by: sector)), source, within: 1e-9))
                (0..<count).forEach { mirror in
                    let line = 0.4 + Double(mirror) * sector / 2
                    #expect(Tests.close(kaleidoscope.source(of: Self.mirrored(point, in: line)), source, within: 1e-9), "\(count) mirrors, mirror \(mirror)")
                }
            }
        }
    }

    @Test
    func `Its 2n wedges alternate between the first and its mirror image, so the spokes close for any n`() {
        for count in [1, 3, 6, 7] {
            let kaleidoscope = Kaleidoscope(center: Self.center, segments: Cardinal(UInt(count)))
            let wedge = Double.pi / Double(count)
            (0..<(2 * count)).forEach { index in
                let point = Self.turned(Tests.at(Self.center[0] + 5, Self.center[1]), by: (Double(index) + 0.5) * wedge)
                #expect(kaleidoscope.wedge(of: point) == Ordinal(UInt(index)))
                #expect(kaleidoscope.spoke(at: point, footprint: 0) == (index % 2 == 1 ? 1 : 0))
                let opposite = Self.turned(point, by: Double.pi)
                let facing = kaleidoscope.spoke(at: opposite, footprint: 0) == kaleidoscope.spoke(at: point, footprint: 0)
                #expect(facing == (count % 2 == 0), "a spoke faces a spoke across the centre only for an even count")
            }
        }
    }

    @Test
    func `Spokes and seam are kept by a turn of one sector, and a reflection in a mirror exchanges spokes for the rest`() {
        let spokes = Picture.Color(red: 0, green: 0, blue: 0)
        let kaleidoscope = Kaleidoscope(
            center: Self.center,
            segments: 6,
            rotation: Radian(0.4),
            seam: .init(Picture.Color(red: 1, green: 1, blue: 1), width: 0.8),
            spokes: spokes
        )
        let read = Tests.pixel(0.2, 0.4, 0.6, 1)
        let sector = Double.pi / 3
        for point in Self.points {
            let pixel = kaleidoscope.pixel(read, at: point, footprint: 1)
            #expect(Tests.close(kaleidoscope.pixel(read, at: Self.turned(point, by: sector), footprint: 1), pixel, within: 1e-5))
            let spoke = kaleidoscope.spoke(at: point, footprint: 1)
            #expect(Tests.close(kaleidoscope.spoke(at: Self.mirrored(point, in: 0.4), footprint: 1), 1 - spoke, within: 1e-9))
            #expect(Tests.close(kaleidoscope.seam(at: Self.mirrored(point, in: 0.4 + sector / 2), footprint: 1), kaleidoscope.seam(at: point, footprint: 1), within: 1e-9))
        }
    }

    @Test
    func `The seam lies on the mirror edges, full there and gone half a footprint past its half width`() {
        let kaleidoscope = Kaleidoscope(center: Self.center, segments: 8, rotation: Radian(0.1), seam: .init(.init(red: 1, green: 1, blue: 1), width: 3))
        (0..<16).forEach { edge in
            for radius in [2.0, 10, 50] {
                let on = Self.turned(Tests.at(Self.center[0] + radius, Self.center[1]), by: 0.1 + Double(edge) * Double.pi / 8)
                #expect(Tests.close(kaleidoscope.distance(of: on), 0, within: 1e-9))
                #expect(kaleidoscope.seam(at: on, footprint: 1) == 1)
                #expect(Tests.close(kaleidoscope.seam(at: Self.mirrored(on, in: 0.1 + Double(edge) * Double.pi / 8 + 0.0001), footprint: 1), 1, within: 1e-9))
            }
        }
        let between = Self.turned(Tests.at(Self.center[0] + 50, Self.center[1]), by: 0.1 + Double.pi / 16)
        #expect(kaleidoscope.distance(of: between) > 2)
        #expect(kaleidoscope.seam(at: between, footprint: 1) == 0)
        let thin = Kaleidoscope(center: Self.center, segments: 8, rotation: Radian(0.1), seam: .init(.init(red: 1, green: 1, blue: 1), width: 0.25))
        let on = Self.turned(Tests.at(Self.center[0] + 20, Self.center[1]), by: 0.1)
        #expect(Tests.close(thin.seam(at: on, footprint: 1), 0.25, within: 1e-12))
        #expect(Kaleidoscope(center: Self.center, segments: 8).seam(at: on, footprint: 1) == 0)
    }

    @Test
    func `Without spokes and seam the pixel is the one read, and a point in the first wedge is held`() {
        let plain = Kaleidoscope(center: Self.center, segments: 5, rotation: Radian(0.2))
        let read = Tests.pixel(0.1, 0.2, 0.3, 0.9)
        for point in Self.points {
            #expect(plain.pixel(read, at: point, footprint: 1) == read)
            #expect(plain.holds(plain.source(of: point)))
        }
        #expect(plain.holds(Self.center))
        #expect(!plain.holds(Self.turned(Tests.at(Self.center[0] + 4, Self.center[1]), by: 0.2 + 0.9 * Double.pi / 5 * 2)))
    }
}
