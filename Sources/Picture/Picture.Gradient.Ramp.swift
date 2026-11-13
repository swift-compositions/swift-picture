extension Picture.Gradient {
    /// A gradient made ready to be read many times: its stops' offsets, and their colours as working pixels,
    /// taken out of sRGB once. `pixel(at:)` is the gradient's own, bit for bit.
    public struct Ramp: Sendable, Hashable {
        public var offsets: [Float]
        public var pixels: [Picture.Pixel]

        public init(_ gradient: Picture.Gradient) {
            self.offsets = gradient.stops.map(\.offset)
            self.pixels = gradient.stops.map(\.color.pixel)
        }
    }
}

extension Picture.Gradient {
    /// This gradient made ready to be read many times.
    public var ramp: Ramp { Ramp(self) }
}

extension Picture.Gradient.Ramp {
    /// The pixel at a parameter.
    public func pixel(at parameter: Float) -> Picture.Pixel {
        guard !pixels.isEmpty else { return .transparent }
        guard parameter > offsets[0] else { return pixels[0] }
        var previous = 0
        var floor = offsets[0]
        var stop = 1
        while stop < pixels.count {
            let offset = Swift.max(offsets[stop], floor)
            if parameter < offset {
                let fraction = (parameter - floor) / (offset - floor)
                return pixels[previous].interpolated(to: pixels[stop], at: fraction)
            }
            previous = stop
            floor = offset
            stop += 1
        }
        return pixels[previous]
    }
}
