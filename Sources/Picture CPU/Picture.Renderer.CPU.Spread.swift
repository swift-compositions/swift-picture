import Picture

extension Picture.Renderer.CPU {
    /// How a blur spreads a sheet along one axis: the Gaussian kernel itself below a deviation of
    /// `Spread.threshold` pixels, and from there on a cascade of boxes whose cost does not grow with the deviation.
    enum Spread {
        case exact(Raster<Picture.Pixel>.Kernel<Float>)
        case boxes(Raster<SIMD4<Float>>.Cascade<Float>)
    }
}

extension Picture.Renderer.CPU.Spread {
    /// The deviation in pixels from which a blur is a cascade of boxes.
    static let threshold: Double = 2

    /// The passes of the cascade.
    static let passes: Int = 5

    /// The spread of a Gaussian of a deviation in pixels, or nil for a deviation that is negative or not finite.
    init?(deviation: Double) {
        do throws(Raster<Picture.Pixel>.Kernel<Float>.Error) {
            if deviation < Self.threshold {
                self = .exact(try .gaussian(deviation: Float(deviation)))
                return
            }
        } catch {
            return nil
        }
        do throws(Raster<SIMD4<Float>>.Kernel<Float>.Error) {
            self = .boxes(try .gaussian(deviation: Float(deviation), count: Self.passes))
        } catch {
            return nil
        }
    }

    /// How far the spread reads beyond a pixel on each side.
    var reach: Int {
        switch self {
        case .exact(let kernel): Int(clamping: kernel.radius)
        case .boxes(let cascade): Int(clamping: cascade.reach)
        }
    }

    /// The pixels as four lanes, red, green, blue and alpha.
    static func lanes(_ pixel: Picture.Pixel) -> SIMD4<Float> {
        SIMD4(pixel.color.red, pixel.color.green, pixel.color.blue, pixel.alpha)
    }

    /// Four lanes as a pixel.
    static func pixel(_ lanes: SIMD4<Float>) -> Picture.Pixel {
        Picture.Pixel(color: .init(red: lanes[0], green: lanes[1], blue: lanes[2]), alpha: lanes[3])
    }

    /// A raster spread across by one spread and down by another, transparent beyond its edge.
    static func applied(_ across: Self, _ down: Self, to raster: Raster<Picture.Pixel>) -> Raster<Picture.Pixel> {
        func mix(_ from: Picture.Pixel, _ to: Picture.Pixel, _ parameter: Float) -> Picture.Pixel {
            from.interpolated(to: to, at: parameter)
        }
        switch (across, down) {
        case (.exact(let horizontal), .exact(let vertical)):
            return raster.convolved(horizontal: horizontal, vertical: vertical, edge: .constant(.transparent), mixing: mix)

        case (.boxes(let horizontal), .boxes(let vertical)):
            return raster.map(lanes).smoothed(horizontal: horizontal, vertical: vertical, edge: .constant(.zero)).map(pixel)

        case (.exact(let horizontal), .boxes(let vertical)):
            let spread = raster.convolved(horizontal: horizontal, vertical: .identity, edge: .constant(.transparent), mixing: mix)
            return spread.map(lanes).smoothed(horizontal: .identity, vertical: vertical, edge: .constant(.zero)).map(pixel)

        case (.boxes(let horizontal), .exact(let vertical)):
            let spread = raster.map(lanes).smoothed(horizontal: horizontal, vertical: .identity, edge: .constant(.zero)).map(pixel)
            return spread.convolved(horizontal: .identity, vertical: vertical, edge: .constant(.transparent), mixing: mix)
        }
    }
}
