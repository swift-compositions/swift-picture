import Picture

extension Picture.Renderer.CPU {
    /// The picture behind a glass, blurred as its frost says, over a box of raster space, read between pixels:
    /// for a large deviation it is kept `factor` times coarser, which a blur that wide cannot tell from the
    /// full raster, and read back bilinearly.
    struct Frost {
        let box: Box
        let factor: Int
        let raster: Raster<Picture.Pixel>

        /// The picture itself, unblurred, and its box, where the frost is not nothing; nil where it is.
        let clear: (raster: Raster<Picture.Pixel>, box: Box)?
    }
}

extension Picture.Renderer.CPU.Frost {
    /// The canvas over a box, blurred by a Gaussian of a deviation in pixels. Beyond the canvas it reads the
    /// canvas's nearest pixel, so the canvas's edge does not darken the blur. The box is grown by the blur's
    /// reach before blurring and read only within the grown box, so what is in the box is blurred as the whole
    /// plane would blur it.
    init(_ canvas: Picture.Renderer.CPU.Canvas, over area: Picture.Renderer.CPU.Box, deviation: Double, _ workers: Picture.Renderer.CPU.Workers) {
        let sigma = deviation.isFinite ? Swift.max(deviation, 0) : 0
        let factor = sigma >= 6 ? Swift.min(Swift.max(Int(sigma / 3), 1), 8) : 1
        let reach = Int((sigma * 4).rounded(.up)) + 2 * factor
        var grown = area.expanded(reach, reach)
        grown = Picture.Renderer.CPU.Box(
            left: grown.left - ((grown.left % factor) + factor) % factor,
            top: grown.top - ((grown.top % factor) + factor) % factor,
            right: grown.right,
            bottom: grown.bottom
        )
        let width = (grown.width + factor - 1) / factor
        let height = (grown.height + factor - 1) / factor
        let source = canvas.box
        func clamped(_ x: Int, _ y: Int) -> Picture.Pixel {
            guard source.area > 0 else { return .transparent }
            let cx = Swift.min(Swift.max(x, source.left), source.right - 1)
            let cy = Swift.min(Swift.max(y, source.top), source.bottom - 1)
            return canvas.pixels[source.index(cx, cy)]
        }
        var small = Picture.Renderer.CPU.Canvas(Picture.Renderer.CPU.Box(left: 0, top: 0, right: width, bottom: height), repeating: .transparent)
        let share = 1 / Float(factor * factor)
        small.update(small.box, workers) { x, y, _ in
            guard factor > 1 else { return clamped(grown.left + x, grown.top + y) }
            var sum = SIMD4<Float>.zero
            var dy = 0
            while dy < factor {
                var dx = 0
                while dx < factor {
                    sum += Picture.Renderer.CPU.Spread.lanes(clamped(grown.left + x * factor + dx, grown.top + y * factor + dy))
                    dx += 1
                }
                dy += 1
            }
            return Picture.Renderer.CPU.Spread.pixel(sum * share)
        }
        var raster = small.raster
        let coarse = factor > 1 ? (Swift.max(sigma * sigma / Double(factor * factor) - 0.25, 0)).squareRoot() : sigma
        if coarse > 0, let spread = Picture.Renderer.CPU.Spread(deviation: coarse) {
            raster = Picture.Renderer.CPU.Spread.applied(spread, spread, to: raster, workers)
        }
        self.init(box: grown, factor: factor, raster: raster, clear: sigma > 0 ? (canvas.raster, canvas.box) : nil)
    }

    /// The picture at a point of raster space where a share `frosting` of the frost is kept: the clear picture
    /// mixed toward the blurred one by that share.
    func read(_ x: Double, _ y: Double, frosting: Double) -> Picture.Pixel {
        let frosted = read(x, y)
        guard let clear, frosting < 1 else { return frosted }
        let sharp = Picture.Renderer.CPU.Canvas.sample(clear.raster, clear.box, x, y, edge: .extend)
        return sharp.interpolated(to: frosted, at: Float(Swift.max(frosting, 0)))
    }

    /// The blurred picture at a point of raster space, bilinearly, the nearest kept pixel beyond the box.
    func read(_ x: Double, _ y: Double) -> Picture.Pixel {
        guard x.isFinite, y.isFinite, raster.width > 0, raster.height > 0 else { return .transparent }
        let scale = Double(factor)
        let point = Point<2, Double>(x: (x - Double(box.left)) / scale, y: (y - Double(box.top)) / scale)
        return raster.sample(at: point, .bilinear, edge: .extend) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }
}
