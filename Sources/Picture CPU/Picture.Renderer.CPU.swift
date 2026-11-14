import Picture

extension Picture.Renderer {
    /// The working parts of the renderer in pure Swift.
    package enum CPU {}
}

extension Picture.Renderer.CPU {
    /// The edition of this renderer's drawing, raised by every change that can change a pixel it draws, so that
    /// a raster kept from an earlier edition is never taken for this one's.
    package static let edition = 5

    /// How far a flattened curve may stray from the true one, in pixels of the raster.
    static let tolerance: Double = 0.1

    /// The most pixels one sheet may hold: past this a layer is refused as `.unsupported`.
    static let limit: Int = 1 << 26

    /// The most pixels a renderer keeps of what it draws for images that name their picture, unless it is told
    /// otherwise: 2²⁵, half a gigabyte.
    static let keeping: Int = 1 << 25

    /// The sum of the squares of a transform's linear part: its largest stretch is at most the root of this.
    static func stretch(_ transform: Picture.Transform) -> Double {
        let a = transform[0, 0]
        let b = transform[0, 1]
        let c = transform[1, 0]
        let d = transform[1, 1]
        return (a * a + b * b + c * c + d * d).squareRoot()
    }

    /// A point of raster space taken through a transform.
    static func point(_ transform: Picture.Transform, _ x: Double, _ y: Double) -> Picture.Plane.Point<2> {
        Affine(transform).point(x, y)
    }

    /// One over each count up to 4097, worked out once: a mean is a sum times one over the count.
    static let shares: [Float] = (0...4097).map { 1 / Float($0) }

    /// One over a count, `1 / Float(count)`, from the table where it holds it.
    @inline(__always)
    static func share(of count: Int) -> Float {
        count >= 0 && count < shares.count ? shares[count] : 1 / Float(count)
    }

    /// A pixel's red, green, blue and alpha as four numbers, to be summed.
    @inline(__always)
    static func components(_ pixel: Picture.Pixel) -> SIMD4<Float> {
        SIMD4(pixel.color.red, pixel.color.green, pixel.color.blue, pixel.alpha)
    }

    /// The mean of `count` pixels whose `components` add up to `sum`: the sum times one over the count. A caller
    /// whose pixels were all one pixel takes that pixel itself, which the sum gives only up to rounding.
    @inline(__always)
    static func mean(_ sum: SIMD4<Float>, of count: Int) -> Picture.Pixel {
        let mean = sum * share(of: count)
        return Picture.Pixel(color: .init(red: mean[0], green: mean[1], blue: mean[2]), alpha: mean[3])
    }

    /// The pixel that ends a change limited to a share `c` of a pixel: what was there plus `c` times the change.
    static func limited(_ old: Picture.Pixel, _ new: Picture.Pixel, _ share: Float?) -> Picture.Pixel {
        guard let share, share != 1 else { return new }
        return old.interpolated(to: new, at: share)
    }
}
