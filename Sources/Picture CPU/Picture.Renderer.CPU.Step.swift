import Numeric
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

        /// The weighted mean of the sheet read at several points for each point, mixed in the order given.
        case blend([(_ x: Double, _ y: Double) -> (x: Double, y: Double)], weights: [Float])

        /// As `map`, with the map made afresh for each band of rows, so that it may keep a cache along the band.
        case field(() -> (_ x: Double, _ y: Double) -> (x: Double, y: Double), reach: Double?)

        /// The sheet's own pixel at each point, changed by a function of the point.
        case tone((_ x: Double, _ y: Double, _ pixel: Picture.Pixel) -> Picture.Pixel)
    }
}

extension Picture.Renderer.CPU.Step {
    /// The segments a zoom's range of scales is cut into: the zoom is drawn as a fine zoom over the first
    /// segment, then a blend of that read at the start of each segment.
    static let segments: Int = 8

    /// The steps for an effect in a layer under a transform: none when the effect changes nothing, two for a
    /// zoom whose scales `1 − amount` to 1 are all positive, one otherwise.
    ///
    /// A zoom of amount a reads the sheet at scales s of the line toward the centre, spread evenly over
    /// [1 − a, 1]. Cut that range into `segments` pieces whose ends are the powers of r = (1 − a)^(1/segments):
    /// the fine zoom of amount 1 − r spreads its reads evenly over [r, 1], and reading its result at scale
    /// r^j moves those onto [r^(j+1), r^j]. Weighting each read by its segment's width, r^j, makes the reads
    /// even over the whole range again, with about a `segments`-th of the reads of one pass.
    static func steps(_ effect: Picture.Effect, _ transform: Picture.Transform, _ inverse: Picture.Transform) throws(Picture.Renderer.Error) -> [Self] {
        guard case .zoom(let zoom) = effect else {
            return try Self(effect, transform, inverse).map { [$0] } ?? []
        }
        guard zoom.amount != 0 else { return [] }
        let low = 1 - zoom.amount
        let ratio = Double.exp(Double.log(low) / Double(segments))
        guard low > 0, low.isFinite, ratio.isFinite else {
            return try Self(effect, transform, inverse).map { [$0] } ?? []
        }
        let fine = Picture.Effect.Zoom(center: zoom.center, amount: 1 - ratio)
        guard let first = try Self(.zoom(fine), transform, inverse) else { return [] }
        var reads: [(_ x: Double, _ y: Double) -> (x: Double, y: Double)] = []
        var weights: [Float] = []
        var scale = 1.0
        var segment = 0
        while segment < segments {
            let shrink = Picture.Effect.Zoom(center: zoom.center, amount: 1 - scale)
            reads.append { x, y in
                let source = shrink.source(of: Picture.Renderer.CPU.point(inverse, x, y), at: 1)
                let moved = transform.applied(to: Vector([source[0], source[1]]))
                return (moved[0], moved[1])
            }
            weights.append(Float(scale))
            scale *= ratio
            segment += 1
        }
        return [first, .blend(reads, weights: weights)]
    }

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
            self = .field(
                {
                    var caches = Picture.Effect.Displacement.Caches()
                    return conjugated { displacement.source(of: $0, caches: &caches) }
                },
                reach: reach.isFinite ? reach : nil
            )

        case .swirl(let swirl):
            guard swirl.angle != 0, swirl.radius > 0 else { return nil }
            let reach = 2 * swirl.radius * Picture.Renderer.CPU.stretch(transform)
            self = .map(conjugated(swirl.source(of:)), reach: reach.isFinite ? reach : nil)

        case .grain(let grain):
            guard grain.amount != 0, grain.size > 0 else { return nil }
            self = .tone { x, y, pixel in grain.pixel(pixel, at: Picture.Renderer.CPU.point(inverse, x, y)) }
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
            return Self.corners(box) { x, y in source(x, y, 1) }.union(box)

        case .map(let source, let reach):
            guard let reach else { return Self.around(box, source) }
            let pixels = Int(Swift.min(reach.rounded(.up), Picture.Renderer.CPU.Box.reach)) + 1
            return box.expanded(pixels, pixels)

        case .blend(let reads, _):
            var total = Picture.Renderer.CPU.Box.empty
            for read in reads { total = total.union(Self.corners(box, read)) }
            return total

        case .field(let make, let reach):
            guard let reach else { return Self.around(box, make()) }
            let pixels = Int(Swift.min(reach.rounded(.up), Picture.Renderer.CPU.Box.reach)) + 1
            return box.expanded(pixels, pixels)

        case .tone:
            return box
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

    /// `around(_:_:)` for a map that is affine, as a zoom's reads at one fraction are: the centres of the box's
    /// four corner pixels are mapped, and the box around them holds the image of every centre between them.
    static func corners(_ box: Picture.Renderer.CPU.Box, _ source: (Double, Double) -> (x: Double, y: Double)) -> Picture.Renderer.CPU.Box {
        guard box.area > 0 else { return .empty }
        let corners = Picture.Renderer.CPU.Box(left: box.left, top: box.top, right: box.left + 1, bottom: box.top + 1)
        let far = (x: box.right - 1, y: box.bottom - 1)
        let points = [(box.left, box.top), (far.x, box.top), (box.left, far.y), (far.x, far.y)]
        var total = Picture.Renderer.CPU.Box.empty
        for (x, y) in points {
            let moved = corners.moved(x - box.left, y - box.top)
            total = total.union(around(moved, source))
        }
        return total
    }

    /// The box outside which the step's result is transparent, given the box outside which its sheet is,
    /// or nil when the step can read from anywhere.
    func support(_ box: Picture.Renderer.CPU.Box?) -> Picture.Renderer.CPU.Box? {
        switch self {
        case .blur(let across, let down): return box?.expanded(across.reach, down.reach)
        case .tone: return box
        case .zoom, .chromatic, .map, .blend, .field: return nil
        }
    }

    /// The step's result over a box, read from a sheet.
    func applied(to sheet: Picture.Renderer.CPU.Canvas, over box: Picture.Renderer.CPU.Box, _ workers: Picture.Renderer.CPU.Workers) -> Picture.Renderer.CPU.Canvas {
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
            let blurred = Picture.Renderer.CPU.Spread.applied(across, down, to: source.raster, workers)
            var result = Picture.Renderer.CPU.Canvas(box, repeating: .transparent)
            result.copy(Picture.Renderer.CPU.Canvas(box: padded, pixels: blurred.pixels))
            return result

        case .zoom(let source):
            return Picture.Renderer.CPU.Canvas(box, workers) { x, y in
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
            return Picture.Renderer.CPU.Canvas(box, workers) { x, y in
                chromatic.pixel(
                    red: read(x - red.x, y - red.y),
                    green: read(x - green.x, y - green.y),
                    blue: read(x - blue.x, y - blue.y)
                )
            }

        case .map(let source, _):
            return Picture.Renderer.CPU.Canvas(box, workers) { x, y in
                let point = source(x, y)
                return read(point.x, point.y)
            }

        case .blend(let reads, let weights):
            return Picture.Renderer.CPU.Canvas(box, workers) { x, y in
                var mean = Picture.Pixel.transparent
                var total: Float = 0
                for (source, weight) in zip(reads, weights) where weight > 0 {
                    let point = source(x, y)
                    let pixel = read(point.x, point.y)
                    total += weight
                    mean = total == weight ? pixel : mean.interpolated(to: pixel, at: weight / total)
                }
                return mean
            }

        case .field(let make, _):
            return Picture.Renderer.CPU.Canvas(
                box,
                workers,
                making: {
                    let source = make()
                    return { x, y in
                        let point = source(x, y)
                        return read(point.x, point.y)
                    }
                }
            )

        case .tone(let change):
            return Picture.Renderer.CPU.Canvas(box, workers) { x, y in change(x, y, read(x, y)) }
        }
    }
}
