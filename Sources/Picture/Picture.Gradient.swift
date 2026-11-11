extension Picture {
    /// Colours along a line from parameter 0 to 1.
    public struct Gradient: Sendable, Hashable {
        public var stops: [Stop]

        public init(_ stops: [Stop]) {
            self.stops = stops
        }
    }
}

extension Picture.Gradient {
    /// The pixel at a parameter.
    public func pixel(at parameter: Float) -> Picture.Pixel {
        guard let first = stops.first else { return .transparent }
        guard parameter > first.offset else { return first.color.pixel }
        var previous = first
        var floor = first.offset
        for stop in stops.dropFirst() {
            let offset = Swift.max(stop.offset, floor)
            if parameter < offset {
                let fraction = (parameter - floor) / (offset - floor)
                return previous.color.pixel.interpolated(to: stop.color.pixel, at: fraction)
            }
            previous = stop
            floor = offset
        }
        return previous.color.pixel
    }
}
