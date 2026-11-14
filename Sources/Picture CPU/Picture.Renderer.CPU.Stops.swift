import Picture

extension Picture.Renderer.CPU {
    /// A gradient's ramp read in place: `pixel(at:)` is `Picture.Gradient.Ramp`'s, step for step, so bit for bit,
    /// with each stop's offset held at least the one before it and one over each gap worked out once.
    @unsafe struct Stops {
        let bounds: UnsafeBufferPointer<Float>
        let reciprocals: UnsafeBufferPointer<Float>
        let pixels: UnsafeBufferPointer<Picture.Pixel>
    }
}

extension Picture.Renderer.CPU.Stops {
    /// Calls `body` with the stops of a ramp.
    static func reading<Result>(_ ramp: Picture.Gradient.Ramp, _ body: (Self) -> Result) -> Result {
        let count = Swift.min(ramp.offsets.count, ramp.pixels.count)
        var bounds: [Float] = []
        var reciprocals: [Float] = []
        bounds.reserveCapacity(count)
        reciprocals.reserveCapacity(count)
        for offset in ramp.offsets.prefix(count) {
            guard let previous = bounds.last else {
                bounds.append(offset)
                reciprocals.append(0)
                continue
            }
            let bound = Swift.max(offset, previous)
            reciprocals.append(1 / (bound - previous))
            bounds.append(bound)
        }
        let known = ramp.offsets.count >= ramp.pixels.count
        return bounds.withUnsafeBufferPointer { bounds in
            reciprocals.withUnsafeBufferPointer { reciprocals in
                ramp.pixels.withUnsafeBufferPointer { pixels in
                    unsafe body(Self(bounds: bounds, reciprocals: reciprocals, pixels: known ? pixels : UnsafeBufferPointer(start: nil, count: 0)))
                }
            }
        }
    }

    /// The pixel at a parameter, as `Picture.Gradient.Ramp.pixel(at:)` reads it.
    @inline(__always)
    func pixel(at parameter: Float) -> Picture.Pixel {
        let count = unsafe pixels.count
        guard count > 0 else { return .transparent }
        let first = unsafe bounds[0]
        guard parameter > first else { return unsafe pixels[0] }
        var stop = 1
        while stop < count {
            let bound = unsafe bounds[stop]
            if parameter < bound {
                let floor = unsafe bounds[stop - 1]
                let reciprocal = unsafe reciprocals[stop]
                return unsafe pixels[stop - 1].interpolated(to: pixels[stop], at: (parameter - floor) * reciprocal)
            }
            stop += 1
        }
        return unsafe pixels[count - 1]
    }
}
