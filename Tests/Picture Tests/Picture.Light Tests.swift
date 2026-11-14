import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `Light falls off, is kept above a threshold, and a gradient is read as a colour` {}
}

extension `Picture Tests`.`Light falls off, is kept above a threshold, and a gradient is read as a colour` {
    typealias Tests = `Picture Tests`

    static let amber = Picture.Color(red: 1, green: 0.7, blue: 0.3, alpha: 0.9)

    @Test(arguments: [0.0, 0.15, 0.4, 1, 3])
    func `A glow's falloff is full at the centre, nothing at and past the radius, and never grows`(core: Double) {
        #expect(Picture.Gradient.falloff(at: 0, core: core) == 1)
        #expect(Picture.Gradient.falloff(at: -2, core: core) == 1)
        #expect(Picture.Gradient.falloff(at: 1, core: core) == 0)
        #expect(Picture.Gradient.falloff(at: 7.5, core: core) == 0)
        #expect(Picture.Gradient.falloff(at: .nan, core: core) == 0)
        let lights = (0...1000).map { Picture.Gradient.falloff(at: Double($0) / 1000, core: core) }
        #expect(zip(lights, lights.dropFirst()).allSatisfy { $1 <= $0 && $1 >= 0 })
        #expect(Picture.Gradient.falloff(at: 0.99, core: core) < 1e-5)
    }

    @Test
    func `Past the window the falloff is the inverse square past its core, half at the core`() {
        let core = 0.4
        let window = (1 - core * core) * (1 - core * core) * (1 - core * core)
        #expect(Tests.close(Picture.Gradient.falloff(at: core, core: core), window / 2))
        #expect(Tests.close(Picture.Gradient.falloff(at: 0.5, core: 0), 0.75 * 0.75 * 0.75))
    }

    @Test
    func `A glow paints the colour at the centre and nothing from the radius on, falling all the way`() {
        let paint = Picture.Paint.falloff(Self.amber, center: Tests.at(10, 20), radius: 50)
        #expect(paint.pixel(at: Tests.at(10, 20)) == Self.amber.pixel)
        #expect(paint.pixel(at: Tests.at(60, 20)).alpha == 0)
        #expect(paint.pixel(at: Tests.at(10, 95)).alpha == 0)
        let pixels = (0...200).map { paint.pixel(at: Tests.at(10 + Double($0) / 4, 20)) }
        #expect(zip(pixels, pixels.dropFirst()).allSatisfy { $1.alpha <= $0.alpha && $1.color.red <= $0.color.red })
        let gradient = Picture.Gradient.falloff(Self.amber, core: 0.3, stops: 9)
        #expect(gradient.stops.count == 9)
        for (step, stop) in gradient.stops.enumerated() {
            let along = Double(step) / 8
            #expect(stop.offset == Float(along * along))
            #expect(stop.color == Self.amber.faded(by: Float(Picture.Gradient.falloff(at: along * along, core: 0.3))))
        }
        #expect(Picture.Gradient.falloff(.white, stops: 0).stops.count == 2)
    }

    @Test
    func `The glow's gradient paints the falloff closely between its stops`() {
        let gradient = Picture.Gradient.falloff(.white)
        let distances = (0...999).map { Double($0) / 999 }
        #expect(
            distances.allSatisfy { distance in
                Tests.close(gradient.pixel(at: Float(distance)).alpha, Float(Picture.Gradient.falloff(at: distance, core: 0.25)), within: 0.0015)
            }
        )
    }

    @Test
    func `A glow element is the square around its circle filled with the glow`() {
        let element = Picture.Element.falloff(.white, center: Tests.at(5, 5), radius: 2)
        guard case .shape(let shape) = element else {
            Issue.record("not a shape")
            return
        }
        #expect(shape.fill?.paint == .falloff(.white, center: Tests.at(5, 5), radius: 2))
        #expect(shape.stroke == nil)
        let box = shape.path.boundingBox
        #expect(box?.llx.underlying == 3 && box?.lly.underlying == 3 && box?.urx.underlying == 7 && box?.ury.underlying == 7)
    }

    @Test
    func `A threshold keeps nothing up to its level and more and more above it, smoothly`() {
        let threshold = Picture.Effect.Threshold(level: 0.5, knee: 0.4)
        #expect(threshold.kept(0) == 0 && threshold.kept(0.5) == 0 && threshold.kept(-1) == 0)
        #expect(Tests.close(threshold.kept(0.9), 0.2))
        #expect(Tests.close(threshold.kept(0.7), 0.05))
        #expect(Tests.close(threshold.kept(2), 1.3))
        let kept = (0...3000).map { threshold.kept(Float($0) / 1000) }
        #expect(zip(kept, kept.dropFirst()).allSatisfy { $1 >= $0 && $1 - $0 <= 0.0011 })
        let cut = Picture.Effect.Threshold(level: 0.25, knee: 0)
        #expect(cut.kept(0.25) == 0 && Tests.close(cut.kept(0.75), 0.5))
    }

    @Test
    func `A threshold keeps a pixel's hue, never more than the pixel, and nothing of a dim one`() {
        let threshold = Picture.Effect.Threshold()
        #expect(threshold.pixel(Tests.pixel(0.3, 0.2, 0.1, 1)) == .transparent)
        #expect(threshold.pixel(.transparent) == .transparent)
        let bright = Tests.pixel(1, 0.5, 0.25, 1)
        let kept = threshold.pixel(bright)
        let share = threshold.kept(1) / 1
        #expect(kept == Tests.pixel(share, 0.5 * share, 0.25 * share, share))
        let hot = Tests.pixel(8, 4, 2, 1)
        #expect(threshold.pixel(hot).alpha <= 1 && threshold.pixel(hot).color.red <= 8)
        #expect(Picture.Effect.Threshold(level: -3, knee: 0).pixel(bright) == bright)
    }

    @Test
    func `A gradient's colour at a stop is the stop, and beyond the ends the end stops`() {
        let stops: [Picture.Gradient.Stop] = [
            .init(offset: 0.1, color: Self.amber),
            .init(offset: 0.4, color: Picture.Color(red: 0.2, green: 0.9, blue: 0.4)),
            .init(offset: 0.4, color: Picture.Color(red: 0.1, green: 0.2, blue: 0.9, alpha: 0.5)),
            .init(offset: 0.8, color: .clear),
            .init(offset: 1, color: .white),
        ]
        let gradient = Picture.Gradient(stops)
        #expect(gradient.color(at: 0.1) == Self.amber)
        #expect(gradient.color(at: -4) == Self.amber)
        #expect(gradient.color(at: .nan) == Self.amber)
        #expect(gradient.color(at: 0.4) == stops[2].color)
        #expect(gradient.color(at: 0.8) == .clear)
        #expect(gradient.color(at: 1) == .white)
        #expect(gradient.color(at: 9) == .white)
        #expect(Picture.Gradient([]).color(at: 0.5) == .clear)
    }

    @Test(arguments: [0.05, 0.17, 0.33, 0.39, 0.52, 0.7, 0.79, 0.85, 0.99])
    func `Between stops a gradient's colour is the pixel it paints there`(parameter: Float) {
        let gradient = Picture.Gradient([
            .init(offset: 0, color: Self.amber),
            .init(offset: 0.4, color: Picture.Color(red: 0.1, green: 0.2, blue: 0.9, alpha: 0.5)),
            .init(offset: 0.8, color: .clear),
            .init(offset: 1, color: .white),
        ])
        #expect(Tests.close(gradient.color(at: parameter).pixel, gradient.pixel(at: parameter), within: 1e-5))
    }

    @Test
    func `A colour made from a pixel is the way back from the pixel`() {
        for color in [Self.amber, .white, .black, Picture.Color(hex: 0x36C8FF, alpha: 0.25)] {
            let back = Picture.Color(color.pixel)
            #expect(Tests.close(back.red, color.red, within: 1e-5) && Tests.close(back.green, color.green, within: 1e-5))
            #expect(Tests.close(back.blue, color.blue, within: 1e-5) && back.alpha == color.alpha)
        }
        #expect(Picture.Color(Picture.Pixel.transparent) == .clear)
    }

    @Test
    func `A ramp's place is where pixel reads between its stops`() {
        let ramp = Picture.Gradient.Ramp(Picture.Gradient([.init(offset: 0.2, color: .black), .init(offset: 0.6, color: .white)]))
        let before = ramp.place(of: 0)
        #expect(before?.from == 0 && before?.to == 0 && before?.fraction == 0)
        let between = ramp.place(of: 0.4)
        #expect(between?.from == 0 && between?.to == 1 && Tests.close(between?.fraction ?? 0, 0.5))
        let after = ramp.place(of: 0.6)
        #expect(after?.from == 1 && after?.to == 1 && after?.fraction == 0)
        #expect(Picture.Gradient.Ramp(Picture.Gradient([])).place(of: 0.5) == nil)
    }
}
