import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A gradient's ramp reads as the gradient does` {}
}

extension `Picture Tests`.`A gradient's ramp reads as the gradient does` {
    typealias Tests = `Picture Tests`

    /// The law of `Picture.Gradient.pixel(at:)` written out, each stop's colour taken out of sRGB when it is read.
    static func plain(_ gradient: Picture.Gradient, at parameter: Float) -> Picture.Pixel {
        guard let first = gradient.stops.first else { return .transparent }
        guard parameter > first.offset else { return first.color.pixel }
        var previous = first
        var floor = first.offset
        for stop in gradient.stops.dropFirst() {
            let offset = Swift.max(stop.offset, floor)
            if parameter < offset {
                return previous.color.pixel.interpolated(to: stop.color.pixel, at: (parameter - floor) / (offset - floor))
            }
            previous = stop
            floor = offset
        }
        return previous.color.pixel
    }

    static let gradients: [Picture.Gradient] = [
        Picture.Gradient([]),
        Picture.Gradient([.init(offset: 0.3, color: .init(red: 0.2, green: 0.4, blue: 0.9, alpha: 0.5))]),
        Picture.Gradient([.init(offset: 0, color: .black), .init(offset: 1, color: .white)]),
        Picture.Gradient([
            .init(offset: 0.1, color: .init(red: 0.96, green: 0.41, blue: 0.18)),
            .init(offset: 0.5, color: .init(red: 0.1, green: 0.8, blue: 0.3, alpha: 0.25)),
            .init(offset: 0.5, color: .init(red: 0.48, green: 0.22, blue: 0.95)),
            .init(offset: 0.4, color: .init(red: 1, green: 1, blue: 0, alpha: 0)),
            .init(offset: 0.9, color: .init(red: 0, green: 0.3, blue: 0.6, alpha: 0.75)),
        ]),
        Picture.Gradient([.init(offset: 0, color: .init(red: 0.9, green: 0.1, blue: 0.4)), .init(offset: 1, color: .init(red: 0.1, green: 0.5, blue: 0.9))])
            .oklab(steps: 7),
    ]

    @Test
    func `At every parameter the ramp, and the gradient through it, give the stops' pixels mixed as the law says, bit for bit`() {
        let parameters: [Float] = (-8...40).map { Float($0) / 32 } + [0.1, 0.4, 0.5, 0.9, .nan, .infinity, -.infinity]
        for gradient in Self.gradients {
            let ramp = gradient.ramp
            #expect(ramp.offsets == gradient.stops.map(\.offset))
            #expect(ramp.pixels == gradient.stops.map(\.color.pixel))
            for parameter in parameters {
                let plain = Self.plain(gradient, at: parameter)
                #expect(ramp.pixel(at: parameter) == plain)
                #expect(gradient.pixel(at: parameter) == plain)
            }
        }
    }
}
