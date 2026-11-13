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
    /// Where a parameter falls among the stops: the stop it goes from, the stop it goes to and how far it is
    /// between them, read as `pixel(at:)` reads them. Before the first offset, and for a parameter that is not
    /// a number, it is the first stop alone; from the last offset on, the last stop alone; a stop alone has
    /// itself as both ends and no way to go. Nil when there are no stops.
    @inlinable
    public func place(of parameter: Float) -> (from: Int, to: Int, fraction: Float)? {
        guard !pixels.isEmpty else { return nil }
        guard parameter > offsets[0] else { return (0, 0, 0) }
        var previous = 0
        var floor = offsets[0]
        var stop = 1
        while stop < pixels.count {
            let offset = Swift.max(offsets[stop], floor)
            if parameter < offset {
                return (previous, stop, (parameter - floor) / (offset - floor))
            }
            previous = stop
            floor = offset
            stop += 1
        }
        return (previous, previous, 0)
    }

    /// The pixel at a parameter.
    @inlinable
    public func pixel(at parameter: Float) -> Picture.Pixel {
        guard let place = place(of: parameter) else { return .transparent }
        guard place.from != place.to else { return pixels[place.from] }
        return pixels[place.from].interpolated(to: pixels[place.to], at: place.fraction)
    }
}
