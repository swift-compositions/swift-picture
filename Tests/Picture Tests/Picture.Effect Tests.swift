import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `An effect reads the sheet at a point it names` {}
}

extension `Picture Tests`.`An effect reads the sheet at a point it names` {
    typealias Tests = `Picture Tests`

    static let degree = Double.pi / 180

    static func polar(_ radius: Double, _ degrees: Double, around center: Picture.Plane.Point<2> = .zero) -> Picture.Plane.Point<2> {
        let radians = degrees * degree
        return Tests.at(center[0] + radius * cosine(radians), center[1] + radius * sine(radians))
    }

    static func sine(_ x: Double) -> Double {
        var term = x
        var sum = x
        (1...24).forEach { step in
            term *= -x * x / Double((2 * step) * (2 * step + 1))
            sum += term
        }
        return sum
    }

    static func cosine(_ x: Double) -> Double {
        var term = 1.0
        var sum = 1.0
        (1...24).forEach { step in
            term *= -x * x / Double((2 * step - 1) * (2 * step))
            sum += term
        }
        return sum
    }

    @Test
    func `Two blurs in a row are one blur whose deviation is the root of the sum of their squares`() {
        typealias Blur = Picture.Effect.Blur
        #expect(Blur(deviation: 3).followed(by: Blur(deviation: 4)) == Blur(deviation: 5))
        #expect(Blur(deviation: 4).followed(by: Blur(deviation: 3)) == Blur(deviation: 5))
        #expect(Blur(deviation: 7).followed(by: Blur(deviation: 0)) == Blur(deviation: 7))
        #expect(Blur(deviation: 0).followed(by: Blur(deviation: 0)) == Blur(deviation: 0))
    }

    @Test
    func `A zoom reads along the line toward its centre, from the point itself to as far as its amount`() {
        let zoom = Picture.Effect.Zoom(center: Tests.at(10, 20), amount: 0.5)
        #expect(zoom.source(of: Tests.at(30, 60), at: 0) == Tests.at(30, 60))
        #expect(zoom.source(of: Tests.at(30, 60), at: 1) == Tests.at(20, 40))
        #expect(zoom.source(of: Tests.at(30, 60), at: 0.5) == Tests.at(25, 50))
        #expect(zoom.source(of: Tests.at(10, 20), at: 0.7) == Tests.at(10, 20))
        let whole = Picture.Effect.Zoom(center: Tests.at(10, 20), amount: 1)
        #expect(whole.source(of: Tests.at(30, 60), at: 1) == Tests.at(10, 20))
        let none = Picture.Effect.Zoom(center: Tests.at(10, 20), amount: 0)
        #expect(none.source(of: Tests.at(30, 60), at: 1) == Tests.at(30, 60))
    }

    @Test
    func `A chromatic split takes red, green and blue from three pixels and the largest of their alphas`() {
        let split = Picture.Effect.Chromatic(red: Vector([2, 0]), blue: Vector([-2, 0]))
        #expect(split.green == .zero)
        let result = split.pixel(red: Tests.pixel(0.1, 0.2, 0.3, 0.4), green: Tests.pixel(0.5, 0.6, 0.7, 0.8), blue: Tests.pixel(0.01, 0.02, 0.03, 0.04))
        #expect(result == Tests.pixel(0.1, 0.6, 0.03, 0.8))
        let same = Tests.pixel(0.25, 0.5, 0.75, 1)
        #expect(split.pixel(red: same, green: same, blue: same) == same)
        #expect(split.pixel(red: Tests.pixel(1, 0, 0, 1), green: .transparent, blue: .transparent) == Tests.pixel(1, 0, 0, 1))
        #expect(split.pixel(red: .transparent, green: .transparent, blue: Tests.pixel(0, 0, 0.5, 0.5)) == Tests.pixel(0, 0, 0.5, 0.5))
    }

    @Test
    func `A pixelation reads the centre of the cell that holds the point`() {
        let cells = Picture.Effect.Pixelation(width: 10, height: 4)
        #expect(cells.origin == .zero)
        #expect(cells.source(of: Tests.at(12, 7)) == Tests.at(15, 6))
        #expect(cells.source(of: Tests.at(10, 4)) == Tests.at(15, 6))
        #expect(cells.source(of: Tests.at(19.99, 7.99)) == Tests.at(15, 6))
        #expect(cells.source(of: Tests.at(-1, -1)) == Tests.at(-5, -2))
        #expect(cells.source(of: cells.source(of: Tests.at(123.4, -56.7))) == cells.source(of: Tests.at(123.4, -56.7)))
        let shifted = Picture.Effect.Pixelation(origin: Tests.at(3, 1), width: 10, height: 4)
        #expect(shifted.source(of: Tests.at(12, 4.5)) == Tests.at(8, 3))
        #expect(shifted.source(of: Tests.at(2, 0)) == Tests.at(-2, -1))
    }

    @Test
    func `A pixelation with a cell that has no size reads the point itself`() {
        #expect(Picture.Effect.Pixelation(width: 0, height: 4).source(of: Tests.at(12, 7)) == Tests.at(12, 7))
        #expect(Picture.Effect.Pixelation(width: 4, height: -1).source(of: Tests.at(12, 7)) == Tests.at(12, 7))
    }

    @Test
    func `A swirl turns a point back about its centre by its angle times the square of the radius left`() {
        let swirl = Picture.Effect.Swirl(center: Tests.at(10, -4), radius: 8, angle: Double.pi)
        #expect(Tests.close(swirl.turn(at: 0), Double.pi))
        #expect(Tests.close(swirl.turn(at: 4), Double.pi / 4))
        #expect(swirl.turn(at: 8) == 0)
        #expect(swirl.turn(at: 20) == 0)
        #expect(Tests.close(swirl.source(of: Self.polar(4, 90, around: Tests.at(10, -4))), Self.polar(4, 45, around: Tests.at(10, -4))))
        #expect(Tests.close(swirl.source(of: Self.polar(2, 0, around: Tests.at(10, -4))), Self.polar(2, -0.5625 * 180, around: Tests.at(10, -4))))
        #expect(swirl.source(of: Tests.at(10, -4)) == Tests.at(10, -4))
        #expect(swirl.source(of: Tests.at(30, 7)) == Tests.at(30, 7))
        #expect(Picture.Effect.Swirl(center: .zero, radius: 0, angle: 3).source(of: Tests.at(0.5, 0)) == Tests.at(0.5, 0))
    }

    @Test
    func `A swirl keeps every point's distance from its centre`() {
        let swirl = Picture.Effect.Swirl(center: Tests.at(3, -2), radius: 12, angle: -2.5)
        [(10.0, 1.0), (-4.0, 7.5), (3.0, -9.0), (3.5, -2.25), (20.0, 20.0)].forEach { x, y in
            let point = Tests.at(x, y)
            let source = swirl.source(of: point)
            let before = ((point[0] - 3) * (point[0] - 3) + (point[1] + 2) * (point[1] + 2)).squareRoot()
            let after = ((source[0] - 3) * (source[0] - 3) + (source[1] + 2) * (source[1] + 2)).squareRoot()
            #expect(Tests.close(before, after))
        }
    }

    @Test
    func `A kaleidoscope reads the mirror image in its first wedge`() {
        let four = Picture.Effect.Kaleidoscope(center: .zero, segments: 4)
        #expect(four.rotation == .zero)
        #expect(Tests.close(four.source(of: Self.polar(5, 10)), Self.polar(5, 10)))
        #expect(Tests.close(four.source(of: Self.polar(5, 44)), Self.polar(5, 44)))
        #expect(Tests.close(four.source(of: Self.polar(5, 80)), Self.polar(5, 10)))
        #expect(Tests.close(four.source(of: Self.polar(5, 100)), Self.polar(5, 10)))
        #expect(Tests.close(four.source(of: Self.polar(5, 170)), Self.polar(5, 10)))
        #expect(Tests.close(four.source(of: Self.polar(5, -10)), Self.polar(5, 10)))
        #expect(Tests.close(four.source(of: Self.polar(5, -100)), Self.polar(5, 10)))
        let six = Picture.Effect.Kaleidoscope(center: Tests.at(100, 50), segments: 6)
        #expect(Tests.close(six.source(of: Self.polar(7, 50, around: Tests.at(100, 50))), Self.polar(7, 10, around: Tests.at(100, 50))))
        #expect(Tests.close(six.source(of: Self.polar(7, 130, around: Tests.at(100, 50))), Self.polar(7, 10, around: Tests.at(100, 50))))
        let one = Picture.Effect.Kaleidoscope(center: .zero, segments: 1)
        #expect(Tests.close(one.source(of: Self.polar(2, 270)), Self.polar(2, 90)))
        #expect(Tests.close(one.source(of: Self.polar(2, 100)), Self.polar(2, 100)))
    }

    @Test
    func `A kaleidoscope keeps the distance from its centre and reads its own result unchanged`() {
        let five = Picture.Effect.Kaleidoscope(center: Tests.at(3, -2), segments: 5, rotation: Radian(0.3))
        [(10.0, 1.0), (-4.0, 7.5), (3.0, -9.0), (-20.0, -20.0), (3.5, -2.25)].forEach { x, y in
            let point = Tests.at(x, y)
            let source = five.source(of: point)
            let before = ((point[0] - 3) * (point[0] - 3) + (point[1] + 2) * (point[1] + 2)).squareRoot()
            let after = ((source[0] - 3) * (source[0] - 3) + (source[1] + 2) * (source[1] + 2)).squareRoot()
            #expect(Tests.close(before, after))
            #expect(Tests.close(five.source(of: source), source))
        }
    }

    @Test
    func `A kaleidoscope's rotation turns where the first wedge starts`() {
        let turned = Picture.Effect.Kaleidoscope(center: .zero, segments: 4, rotation: Radian(20 * Self.degree))
        #expect(Tests.close(turned.source(of: Self.polar(5, 30)), Self.polar(5, 30)))
        #expect(Tests.close(turned.source(of: Self.polar(5, 100)), Self.polar(5, 30)))
        #expect(Tests.close(turned.source(of: Self.polar(5, 10)), Self.polar(5, 30)))
        #expect(Tests.close(turned.source(of: Self.polar(5, 120)), Self.polar(5, 30)))
    }

    @Test
    func `A kaleidoscope with no segments, and its own centre, read the point itself`() {
        let none = Picture.Effect.Kaleidoscope(center: .zero, segments: 0)
        #expect(none.source(of: Tests.at(-3, 4)) == Tests.at(-3, 4))
        let four = Picture.Effect.Kaleidoscope(center: Tests.at(1, 1), segments: 4)
        #expect(four.source(of: Tests.at(1, 1)) == Tests.at(1, 1))
    }

    @Test
    func `A displacement moves each point by its noise field, at most the amplitude along each axis`() {
        let field = Picture.Effect.Displacement(seed: Threefry.Key(7, 11), frequency: 0.05, amplitude: 12)
        #expect(field.phase == 0)
        var moved = false
        [(0.5, 0.5), (13.25, 40.75), (-7.5, 3.125), (250.5, -19.5), (999.25, 1000.5)].forEach { x, y in
            let point = Tests.at(x, y)
            let offset = field.offset(at: point)
            #expect(abs(offset[0]) <= 12)
            #expect(abs(offset[1]) <= 12)
            #expect(field.source(of: point) == Tests.at(x + offset[0], y + offset[1]))
            moved = moved || offset != .zero
            #expect(offset[0] != offset[1])
        }
        #expect(moved)
    }

    @Test
    func `A displacement is the noise of swift-noise: x from the seed, y from the seed with its second word one higher`() {
        let seed = Threefry.Key(7, 11)
        let field = Picture.Effect.Displacement(seed: seed, frequency: 0.25, amplitude: 8, phase: 0.75)
        let point = Tests.at(13.5, -2.25)
        let position = Point<3, Double>([13.5 * 0.25, -2.25 * 0.25, 0.75])
        let offset = field.offset(at: point)
        #expect(offset[0] == 8 * Noise<3, Double>(seed: seed).value(at: position))
        #expect(offset[1] == 8 * Noise<3, Double>(seed: Threefry.Key(7, 12)).value(at: position))
        #expect(Picture.Effect.Displacement(seed: seed, frequency: 0.25, amplitude: 8, phase: 0.5).offset(at: point) != offset)
        #expect(Picture.Effect.Displacement(seed: Threefry.Key(8, 11), frequency: 0.25, amplitude: 8, phase: 0.75).offset(at: point) != offset)
    }

    @Test
    func `A displacement is zero with no amplitude and on the noise lattice`() {
        let still = Picture.Effect.Displacement(seed: Threefry.Key(1, 2), frequency: 0.3, amplitude: 0)
        #expect(still.source(of: Tests.at(4.2, 9.9)) == Tests.at(4.2, 9.9))
        let field = Picture.Effect.Displacement(seed: Threefry.Key(1, 2), frequency: 0.5, amplitude: 100, phase: 3)
        #expect(field.offset(at: Tests.at(4, -6)) == .zero)
        #expect(field.source(of: Tests.at(10, 2)) == Tests.at(10, 2))
        #expect(field.offset(at: Tests.at(4.5, -6)) != .zero)
    }
}

extension `Picture Tests`.`An effect reads the sheet at a point it names` {
    @Test
    func `A displacement read through caches gives the offsets it gives without, bit for bit`() {
        let field = Picture.Effect.Displacement(seed: Threefry.Key(7, 11), frequency: 0.05, amplitude: 12, phase: 0.3)
        var caches = Picture.Effect.Displacement.Caches()
        var step = 0
        while step < 300 {
            let point = Tests.at(Double(step) * 0.77 - 40, Double(step % 23) * 3.1)
            #expect(field.offset(at: point, caches: &caches) == field.offset(at: point))
            #expect(field.source(of: point, caches: &caches) == field.source(of: point))
            step += 1
        }
    }
}

extension `Picture Tests`.`An effect reads the sheet at a point it names` {
    @Test
    func `A grain's share lies within -1 and 1, is one all over a cell, and follows from the seed and the cell alone`() {
        let grain = Picture.Effect.Grain(seed: Threefry.Key(3, 9), amount: 0.2, size: 4)
        var shares: Set<Double> = []
        var total = 0.0
        (0..<10_000).forEach { (cell: Int) in
            let corner = Tests.at(Double(cell % 100 - 50) * 4, Double(cell / 100 - 50) * 4)
            let share = grain.share(at: corner)
            #expect(share >= -1 && share < 1)
            #expect(grain.share(at: Tests.at(corner[0] + 3.9, corner[1] + 2.5)) == share)
            shares.insert(share)
            total += share
        }
        #expect(shares.count > 9_900)
        #expect(abs(total / 10_000) < 0.02)
        let point = Tests.at(13.5, -7.25)
        #expect(Picture.Effect.Grain(seed: Threefry.Key(3, 9), amount: 0.7, size: 4).share(at: point) == grain.share(at: point))
        #expect(Picture.Effect.Grain(seed: Threefry.Key(3, 10), amount: 0.2, size: 4).share(at: point) != grain.share(at: point))
        #expect(Picture.Effect.Grain(seed: Threefry.Key(3, 9), amount: 0.2, size: 0).share(at: point) == 0)
    }

    @Test
    func `A grain moves red, green and blue alike by its amount times the share times alpha, within none and alpha`() {
        let grain = Picture.Effect.Grain(seed: Threefry.Key(1, 2), amount: 0.1)
        var seen = (lighter: false, darker: false)
        (0..<200).forEach { (step: Int) in
            let point = Tests.at(Double(step) + 0.5, Double(step % 7) + 0.5)
            let change = Float(0.1 * grain.share(at: point)) * 0.5
            seen = (seen.lighter || change > 0, seen.darker || change < 0)
            let moved = grain.pixel(Tests.pixel(0.2, 0.25, 0.3, 0.5), at: point)
            #expect(Tests.close(moved, Tests.pixel(0.2 + change, 0.25 + change, 0.3 + change, 0.5)))
            #expect(grain.pixel(.transparent, at: point) == .transparent)
            let dark = grain.pixel(Tests.pixel(0, 0.001, 0, 1), at: point)
            #expect(dark.color.red >= 0 && dark.color.green >= 0 && dark.alpha == 1)
            let bright = grain.pixel(Tests.pixel(1, 0.999, 1, 1), at: point)
            #expect(bright.color.red <= 1 && bright.color.green <= 1)
        }
        #expect(seen.lighter && seen.darker)
    }
}

extension `Picture Tests`.`An effect reads the sheet at a point it names` {
    @Test
    func `A grain's shares and a displacement's offsets are the values recorded, bit for bit`() {
        // Golden values: a change in swift-threefry or swift-noise, or in how these read them, fails here.
        let grain = Picture.Effect.Grain(seed: Threefry.Key(3, 9), amount: 0.2, size: 4)
        #expect(grain.share(at: Tests.at(0.5, 0.5)).bitPattern == 13_819_737_663_767_960_468)
        #expect(grain.share(at: Tests.at(13.5, -7.25)).bitPattern == 13_823_245_104_484_283_540)
        #expect(grain.share(at: Tests.at(-101, 57.3)).bitPattern == 4_596_420_736_674_907_984)
        let field = Picture.Effect.Displacement(seed: Threefry.Key(7, 11), frequency: 0.05, amplitude: 12, phase: 0.3)
        let recorded: [(Double, Double, UInt64, UInt64)] = [
            (0.5, 0.5, 13_828_841_375_918_692_656, 13_819_341_374_339_716_724),
            (13.25, 40.75, 13_826_835_500_910_911_757, 4_604_319_684_113_623_566),
            (-250.5, 19.5, 13_828_717_710_861_953_176, 13_826_602_545_813_454_359),
        ]
        for (x, y, across, down) in recorded {
            let offset = field.offset(at: Tests.at(x, y))
            #expect(offset[0].bitPattern == across && offset[1].bitPattern == down, "at (\(x), \(y))")
        }
    }
}
