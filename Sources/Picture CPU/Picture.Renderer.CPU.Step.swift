import Picture

extension Picture.Renderer.CPU {
    /// One effect of a layer as the renderer applies it to a sheet in raster space: the effect's own
    /// map conjugated by the transform from the layer's space, so `T ∘ f ∘ T⁻¹`.
    enum Step {
        /// A separable Gaussian along the raster's axes.
        case blur(Spread, Spread)

        /// A mean along the stretch toward the zoom's centre: the point read at a fraction of the way.
        case zoom((_ x: Double, _ y: Double, _ fraction: Double) -> (x: Double, y: Double))

        /// Red, green and blue read at their own offsets in raster space.
        case chromatic(Picture.Effect.Chromatic, red: (x: Double, y: Double), green: (x: Double, y: Double), blue: (x: Double, y: Double))

        /// The sheet read at one point for each point; `reach`, when known, bounds how far in raster space
        /// that point lies from the point itself along each axis.
        case map((_ x: Double, _ y: Double) -> (x: Double, y: Double), reach: Double?)
    }
}

extension Picture.Renderer.CPU.Step {
    /// The step for an effect in a layer under a transform, or nil when the effect changes nothing.
    init?(_ effect: Picture.Effect, _ transform: Picture.Transform, _ inverse: Picture.Transform) throws(Picture.Renderer.Error) {
        func conjugated(_ map: @escaping (Picture.Plane.Point<2>) -> Picture.Plane.Point<2>) -> (Double, Double) -> (x: Double, y: Double) {
            { x, y in
                let source = map(Picture.Renderer.CPU.point(inverse, x, y))
                let moved = transform.applied(to: Vector([source[0], source[1]]))
                return (moved[0], moved[1])
            }
        }
        func linear(_ offset: Vector<2, Double>) -> (x: Double, y: Double) {
            (
                transform[0, 0] * offset[0] + transform[0, 1] * offset[1],
                transform[1, 0] * offset[0] + transform[1, 1] * offset[1]
            )
        }
        switch effect {
        case .blur(let blur):
            guard blur.deviation > 0 else { return nil }
            let a = transform[0, 0]
            let b = transform[0, 1]
            let c = transform[1, 0]
            let d = transform[1, 1]
            let skew = a * c + b * d
            guard abs(skew) <= 1e-12 * (a * a + b * b + c * c + d * d) else { throw .unsupported }
            let across = blur.deviation * (a * a + b * b).squareRoot()
            let down = blur.deviation * (c * c + d * d).squareRoot()
            guard let horizontal = Picture.Renderer.CPU.Spread(deviation: across), let vertical = Picture.Renderer.CPU.Spread(deviation: down) else {
                throw .unsupported
            }
            self = .blur(horizontal, vertical)

        case .zoom(let zoom):
            guard zoom.amount != 0 else { return nil }
            self = .zoom { x, y, fraction in
                let source = zoom.source(of: Picture.Renderer.CPU.point(inverse, x, y), at: fraction)
                let moved = transform.applied(to: Vector([source[0], source[1]]))
                return (moved[0], moved[1])
            }

        case .chromatic(let chromatic):
            self = .chromatic(chromatic, red: linear(chromatic.red), green: linear(chromatic.green), blue: linear(chromatic.blue))

        case .pixelation(let pixelation):
            guard pixelation.width > 0, pixelation.height > 0 else { return nil }
            self = .map(conjugated(pixelation.source(of:)), reach: nil)

        case .kaleidoscope(let kaleidoscope):
            guard kaleidoscope.segments > .zero else { return nil }
            self = .map(conjugated(kaleidoscope.source(of:)), reach: nil)

        case .displacement(let displacement):
            let reach = 2.0.squareRoot() * abs(displacement.amplitude) * Picture.Renderer.CPU.stretch(transform)
            self = .map(conjugated(displacement.source(of:)), reach: reach.isFinite ? reach : nil)

        case .swirl(let swirl):
            guard swirl.angle != 0, swirl.radius > 0 else { return nil }
            let reach = 2 * swirl.radius * Picture.Renderer.CPU.stretch(transform)
            self = .map(conjugated(swirl.source(of:)), reach: reach.isFinite ? reach : nil)
        }
    }

    /// The box of the sheet before this step that the step reads to make the pixels of `box`.
    func reads(_ box: Picture.Renderer.CPU.Box) -> Picture.Renderer.CPU.Box {
        guard box.area > 0 else { return .empty }
        switch self {
        case .blur(let across, let down):
            return box.expanded(across.reach, down.reach)

        case .chromatic(_, let red, let green, let blue):
            var total = Picture.Renderer.CPU.Box.empty
            for offset in [red, green, blue] {
                total = total.union(Self.around(box) { x, y in (x - offset.x, y - offset.y) })
            }
            return total

        case .zoom(let source):
            return Self.around(box) { x, y in source(x, y, 1) }.union(box)

        case .map(let source, let reach):
            guard let reach else { return Self.around(box, source) }
            let pixels = Int(Swift.min(reach.rounded(.up), Picture.Renderer.CPU.Box.reach)) + 1
            return box.expanded(pixels, pixels)
        }
    }

    /// The box whose pixels a bilinear read touches at every point a map gives for the pixel centres of a box.
    static func around(_ box: Picture.Renderer.CPU.Box, _ source: (Double, Double) -> (x: Double, y: Double)) -> Picture.Renderer.CPU.Box {
        var low = (x: Double.infinity, y: Double.infinity)
        var high = (x: -Double.infinity, y: -Double.infinity)
        var y = box.top
        while y < box.bottom {
            var x = box.left
            while x < box.right {
                let point = source(Double(x) + 0.5, Double(y) + 0.5)
                if point.x.isFinite, point.y.isFinite {
                    low = (Swift.min(low.x, point.x), Swift.min(low.y, point.y))
                    high = (Swift.max(high.x, point.x), Swift.max(high.y, point.y))
                }
                x += 1
            }
            y += 1
        }
        guard low.x <= high.x, low.y <= high.y else { return .empty }
        let reach = Picture.Renderer.CPU.Box.reach
        let left = Int(Swift.max((low.x - 0.5).rounded(.down), -reach))
        let top = Int(Swift.max((low.y - 0.5).rounded(.down), -reach))
        let right = Int(Swift.min((high.x - 0.5).rounded(.down), reach)) + 2
        let bottom = Int(Swift.min((high.y - 0.5).rounded(.down), reach)) + 2
        return Picture.Renderer.CPU.Box(left: left, top: top, right: right, bottom: bottom)
    }

    /// The box outside which the step's result is transparent, given the box outside which its sheet is,
    /// or nil when the step can read from anywhere.
    func support(_ box: Picture.Renderer.CPU.Box?) -> Picture.Renderer.CPU.Box? {
        guard case .blur(let across, let down) = self else { return nil }
        return box?.expanded(across.reach, down.reach)
    }

    /// The step's result over a box, read from a sheet.
    func applied(to sheet: Picture.Renderer.CPU.Canvas, over box: Picture.Renderer.CPU.Box) -> Picture.Renderer.CPU.Canvas {
        guard box.area > 0 else { return Picture.Renderer.CPU.Canvas(box, repeating: .transparent) }
        let raster = sheet.raster
        func read(_ x: Double, _ y: Double) -> Picture.Pixel {
            Picture.Renderer.CPU.Canvas.sample(raster, sheet.box, x, y)
        }
        switch self {
        case .blur(let across, let down):
            let padded = box.expanded(across.reach, down.reach)
            var source = Picture.Renderer.CPU.Canvas(padded, repeating: .transparent)
            source.copy(sheet)
            let blurred = Picture.Renderer.CPU.Spread.applied(across, down, to: source.raster)
            var result = Picture.Renderer.CPU.Canvas(box, repeating: .transparent)
            result.copy(Picture.Renderer.CPU.Canvas(box: padded, pixels: blurred.pixels))
            return result

        case .zoom(let source):
            return Picture.Renderer.CPU.Canvas(box) { x, y in
                let end = source(x, y, 1)
                let across = end.x - x
                let down = end.y - y
                let length = (across * across + down * down).squareRoot()
                let count = length.isFinite ? Int(Swift.min(Swift.max(length.rounded(.up), 1), 4096)) : 1
                var mean = Picture.Pixel.transparent
                var step = 0
                while step < count {
                    let point = source(x, y, (Double(step) + 0.5) / Double(count))
                    let pixel = read(point.x, point.y)
                    mean = step == 0 ? pixel : mean.interpolated(to: pixel, at: 1 / Float(step + 1))
                    step += 1
                }
                return mean
            }

        case .chromatic(let chromatic, let red, let green, let blue):
            return Picture.Renderer.CPU.Canvas(box) { x, y in
                chromatic.pixel(
                    red: read(x - red.x, y - red.y),
                    green: read(x - green.x, y - green.y),
                    blue: read(x - blue.x, y - blue.y)
                )
            }

        case .map(let source, _):
            return Picture.Renderer.CPU.Canvas(box) { x, y in
                let point = source(x, y)
                return read(point.x, point.y)
            }
        }
    }
}
