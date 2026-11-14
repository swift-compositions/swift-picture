import Picture

extension Picture.Renderer.CPU {
    /// A gradient's ramp read in place, without copying its arrays: `pixel(at:)` is `Picture.Gradient.Ramp`'s,
    /// step for step, so bit for bit.
    @unsafe struct Stops {
        let offsets: UnsafeBufferPointer<Float>
        let pixels: UnsafeBufferPointer<Picture.Pixel>
    }
}

extension Picture.Renderer.CPU.Stops {
    /// Calls `body` with the stops of a ramp.
    static func reading<Result>(_ ramp: Picture.Gradient.Ramp, _ body: (Self) -> Result) -> Result {
        ramp.offsets.withUnsafeBufferPointer { offsets in
            ramp.pixels.withUnsafeBufferPointer { pixels in
                unsafe body(Self(offsets: offsets, pixels: pixels))
            }
        }
    }

    /// The pixel at a parameter, as `Picture.Gradient.Ramp.pixel(at:)` reads it.
    @inline(__always)
    func pixel(at parameter: Float) -> Picture.Pixel {
        let count = unsafe pixels.count
        let known = unsafe offsets.count
        guard count > 0, known >= count else { return .transparent }
        let first = unsafe offsets[0]
        guard parameter > first else { return unsafe pixels[0] }
        var previous = 0
        var floor = first
        var stop = 1
        while stop < count {
            let next = unsafe offsets[stop]
            let offset = Swift.max(next, floor)
            if parameter < offset {
                return unsafe pixels[previous].interpolated(to: pixels[stop], at: (parameter - floor) / (offset - floor))
            }
            previous = stop
            floor = offset
            stop += 1
        }
        return unsafe pixels[previous]
    }
}
