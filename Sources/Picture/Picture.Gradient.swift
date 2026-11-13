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
    /// The pixel at a parameter. A renderer that reads many pixels of one gradient reads them from its `ramp`,
    /// which takes the stops' colours out of sRGB once.
    public func pixel(at parameter: Float) -> Picture.Pixel {
        ramp.pixel(at: parameter)
    }

    /// The colour at a parameter, as written: the stop's own colour where the parameter falls on a stop or
    /// beyond the ends, and between two stops the colour of the pixel `pixel(at:)` gives there, by
    /// `Picture.Color(_:)`. The gradient mixes in linear light, premultiplied, and so does this. No stops
    /// give `clear`.
    public func color(at parameter: Float) -> Picture.Color {
        let ramp = self.ramp
        guard let place = ramp.place(of: parameter) else { return .clear }
        guard place.from != place.to, place.fraction != 0 else { return stops[place.from].color }
        return Picture.Color(ramp.pixels[place.from].interpolated(to: ramp.pixels[place.to], at: place.fraction))
    }
}

extension Picture.Gradient {
    /// How much of a glow's light is left at a distance from its centre, in radii: 1 at the centre, 0 from 1
    /// on, and never growing on the way. It is light that falls as the inverse square of the distance past a
    /// `core`, `1 / (1 + (d / core)²)`, which is half at the core, brought to nothing at the radius by the
    /// window `(1 − d²)³`. The window meets 0 with no slope and no bend, so slowly that the light's sRGB
    /// encoding, which lifts faint light most, also meets 0 with no slope: a glow fades out and shows no edge.
    /// A core that is not positive leaves the window alone; a distance that is not a number has no light.
    public static func falloff(at distance: Double, core: Double) -> Double {
        guard distance > 0 else { return distance.isNaN ? 0 : 1 }
        guard distance < 1 else { return 0 }
        let square = distance * distance
        let window = (1 - square) * (1 - square) * (1 - square)
        guard core > 0 else { return window }
        return window / (1 + square / (core * core))
    }

    /// The light of a glow from its centre (parameter 0) to its radius (parameter 1): the colour with its alpha
    /// multiplied by `falloff(at:core:)` at `stops` offsets from 0 to 1, at least two, the i-th of n at
    /// (i / (n − 1))², closer together near the centre where the light bends most. Past 1 it is clear. The
    /// gradient is read straight between the stops, in linear light: with the default 32 stops it paints the
    /// falloff to within 0.0015 of the colour for the default core, and within 0.003 for any core from 0.1.
    public static func glow(_ color: Picture.Color, core: Double = 0.25, stops: Cardinal = 32) -> Self {
        let count = Swift.max(Int(clamping: stops), 2)
        return Self(
            (0..<count).map { step in
                let along = Double(step) / Double(count - 1)
                let offset = along * along
                return Stop(offset: Float(offset), color: color.faded(by: Float(falloff(at: offset, core: core))))
            }
        )
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
