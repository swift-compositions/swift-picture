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
    static let passes: Cardinal = 5

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

    /// A raster spread across by one spread and down by another, transparent beyond its edge. Across, the
    /// workers take bands of whole rows; down, strips of whole columns, so each line is spread as it would be alone.
    static func applied(
        _ across: Self,
        _ down: Self,
        to raster: Raster<Picture.Pixel>,
        _ workers: Picture.Renderer.CPU.Workers
    ) -> Raster<Picture.Pixel> {
        let spread = split(raster, down: false, workers) { across.spread($0, down: false) }
        return split(spread, down: true, workers) { down.spread($0, down: true) }
    }

    /// A raster spread along one axis.
    func spread(_ raster: Raster<Picture.Pixel>, down: Bool) -> Raster<Picture.Pixel> {
        switch self {
        case .exact(let kernel):
            return raster.convolved(
                horizontal: down ? .identity : kernel,
                vertical: down ? kernel : .identity,
                edge: .constant(.transparent)
            ) { from, to, parameter in
                from.interpolated(to: to, at: parameter)
            }

        case .boxes(let cascade):
            return raster.map(Self.lanes)
                .smoothed(horizontal: down ? .identity : cascade, vertical: down ? cascade : .identity, edge: .constant(.zero))
                .map(Self.pixel)
        }
    }

    /// A raster with `apply` made of each band of rows, or with `down` each strip of columns, the workers
    /// taking the bands, put back together in place.
    static func split(
        _ raster: Raster<Picture.Pixel>,
        down: Bool,
        _ workers: Picture.Renderer.CPU.Workers,
        _ apply: (Raster<Picture.Pixel>) -> Raster<Picture.Pixel>
    ) -> Raster<Picture.Pixel> {
        let width = Int(bitPattern: raster.width)
        let height = Int(bitPattern: raster.height)
        guard workers.count > 1, width * height >= 2 * Picture.Renderer.CPU.Workers.worth else { return apply(raster) }
        let size = down ? Picture.Renderer.CPU.Workers.rows(across: height) : Picture.Renderer.CPU.Workers.rows(across: width)
        let total = down ? width : height
        var canvas = Picture.Renderer.CPU.Canvas(raster)
        let source = raster
        let box = canvas.box
        canvas.pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
            workers.run((total + size - 1) / size) { part in
                let start = part * size
                let count = Swift.min(size, total - start)
                let region = Raster<Picture.Pixel>.Region(
                    x: Ordinal(UInt(down ? start : 0)),
                    y: Ordinal(UInt(down ? 0 : start)),
                    width: Cardinal(UInt(down ? count : width)),
                    height: Cardinal(UInt(down ? height : count))
                )
                let piece: Raster<Picture.Pixel>
                do throws(Raster<Picture.Pixel>.Error) {
                    piece = apply(try source.cropped(to: region))
                } catch {
                    preconditionFailure("A band lies inside its raster")
                }
                let columns = down ? count : width
                for (index, pixel) in zip(piece.pixels.indices, piece.pixels) {
                    let x = (down ? start : 0) + index % columns
                    let y = (down ? 0 : start) + index / columns
                    unsafe shared[box.index(x, y)] = pixel
                }
            }
        }
        return canvas.raster
    }
}
