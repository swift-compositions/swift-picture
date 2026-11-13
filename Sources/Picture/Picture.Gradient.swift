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

extension Picture.Gradient {
    /// This gradient going from stop to stop through Oklab: each stretch between two stops becomes `steps`
    /// equal stretches, and the stops put between take the two stops' colours mixed in Oklab by
    /// `Picture.Color.mixed(inOklabTo:at:)`. Each short stretch is still read in linear light, so more steps
    /// come closer to Oklab at every parameter. Two stops at one offset stay a hard edge with nothing between,
    /// and fewer than two steps, or fewer than two stops, give the gradient back as it is.
    public func oklab(steps: Cardinal) -> Self {
        let count = Int(clamping: steps)
        guard count > 1, let first = stops.first else { return self }
        var result: [Stop] = [first]
        var previous = first
        var floor = first.offset
        stops.dropFirst().forEach { stop in
            let offset = Swift.max(stop.offset, floor)
            if offset > floor {
                let (from, low) = (previous.color, floor)
                result.append(
                    contentsOf: (1..<count).map { step in
                        let share = Double(step) / Double(count)
                        return Stop(offset: low + (offset - low) * Float(share), color: from.mixed(inOklabTo: stop.color, at: share))
                    }
                )
            }
            result.append(stop)
            previous = stop
            floor = offset
        }
        return Self(result)
    }
}
