import Numeric
import Picture
import Synchronization

extension Picture.Renderer.CPU {
    /// Working pixels over a box of raster space: the raster itself, or a layer's sheet.
    struct Canvas {
        var box: Box
        var pixels: [Picture.Pixel]
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// A canvas over a box, every pixel the same.
    init(_ box: Picture.Renderer.CPU.Box, repeating pixel: Picture.Pixel) {
        self.init(box: box, pixels: [Picture.Pixel](repeating: pixel, count: box.area))
    }

    /// A canvas holding a raster's pixels at the raster's own place.
    init(_ raster: Raster<Picture.Pixel>) {
        self.init(
            box: Picture.Renderer.CPU.Box(left: 0, top: 0, right: Int(clamping: raster.width), bottom: Int(clamping: raster.height)),
            pixels: raster.pixels
        )
    }

    /// The canvas as a raster of its own size, its first pixel being the box's first.
    var raster: Raster<Picture.Pixel> {
        do throws(Raster<Picture.Pixel>.Error) {
            return try Raster(width: Cardinal(UInt(box.width)), height: Cardinal(UInt(box.height)), pixels: pixels)
        } catch {
            preconditionFailure("A canvas holds one pixel for each pixel of its box")
        }
    }

    /// A canvas over a box whose pixels are a function of their centres in raster space, band by band on the workers.
    init(_ box: Picture.Renderer.CPU.Box, _ workers: Picture.Renderer.CPU.Workers, _ pixel: (_ x: Double, _ y: Double) -> Picture.Pixel) {
        self.init(box, repeating: .transparent)
        update(box, workers) { x, y, _ in pixel(Double(x) + 0.5, Double(y) + 0.5) }
    }

    /// A canvas over a box whose pixels are a function of their centres, made afresh for each band of rows by
    /// `make`, so that the function may keep what it learns along a band, such as a cache.
    init(
        _ box: Picture.Renderer.CPU.Box,
        _ workers: Picture.Renderer.CPU.Workers,
        making make: () -> (_ x: Double, _ y: Double) -> Picture.Pixel
    ) {
        self.init(box, repeating: .transparent)
        update(
            box,
            workers,
            making: {
                let pixel = make()
                return { x, y, _ in pixel(Double(x) + 0.5, Double(y) + 0.5) }
            }
        )
    }

    /// Gives each pixel of an area of the canvas the value `pixel` makes of its position and its pixel as it was.
    /// The area is cut into bands of rows and the workers take the bands; each pixel is computed the same way
    /// whichever thread takes it.
    mutating func update(
        _ area: Picture.Renderer.CPU.Box,
        _ workers: Picture.Renderer.CPU.Workers,
        _ pixel: (_ x: Int, _ y: Int, _ old: Picture.Pixel) -> Picture.Pixel
    ) {
        withoutActuallyEscaping(pixel) { pixel in
            update(area, workers, making: { pixel })
        }
    }

    /// `update(_:_:_:)` with the function made afresh for each band by `make`.
    mutating func update(
        _ area: Picture.Renderer.CPU.Box,
        _ workers: Picture.Renderer.CPU.Workers,
        making make: () -> (_ x: Int, _ y: Int, _ old: Picture.Pixel) -> Picture.Pixel
    ) {
        let area = area.intersection(box)
        guard area.area > 0 else { return }
        let box = self.box
        let band = Picture.Renderer.CPU.Workers.rows(across: area.width)
        let bands = (area.height + band - 1) / band
        pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
            workers.run(bands) { part in
                let pixel = make()
                var y = area.top + part * band
                let end = Swift.min(y + band, area.bottom)
                while y < end {
                    var x = area.left
                    var index = box.index(x, y)
                    while x < area.right {
                        unsafe shared[index] = pixel(x, y, unsafe shared[index])
                        x += 1
                        index += 1
                    }
                    y += 1
                }
            }
        }
    }

    /// Calls `body` for each row of an area of the canvas, in the same bands of rows as `update`, with the row,
    /// its columns in the area, the canvas's pixels and the index of the row's first pixel there. The area is
    /// cut to the canvas.
    mutating func rows(
        _ area: Picture.Renderer.CPU.Box,
        _ workers: Picture.Renderer.CPU.Workers,
        _ body: (_ y: Int, _ columns: Range<Int>, _ pixels: Picture.Renderer.CPU.Workers.Pixels, _ start: Int) -> Void
    ) {
        let area = area.intersection(box)
        guard area.area > 0 else { return }
        let box = self.box
        let band = Picture.Renderer.CPU.Workers.rows(across: area.width)
        let bands = (area.height + band - 1) / band
        pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
            workers.run(bands) { part in
                var y = area.top + part * band
                let end = Swift.min(y + band, area.bottom)
                while y < end {
                    unsafe body(y, area.left..<area.right, shared, box.index(area.left, y))
                    y += 1
                }
            }
        }
    }

    /// Copies another canvas's pixels where the two boxes overlap.
    mutating func copy(_ other: Self) {
        let common = box.intersection(other.box)
        var y = common.top
        while y < common.bottom {
            var x = common.left
            while x < common.right {
                pixels[box.index(x, y)] = other.pixels[other.box.index(x, y)]
                x += 1
            }
            y += 1
        }
    }

    /// The pixel at a position of raster space, transparent outside the box.
    subscript(x: Int, y: Int) -> Picture.Pixel {
        box.contains(x, y) ? pixels[box.index(x, y)] : .transparent
    }

    /// The canvas read at a point of raster space between pixel centres, transparent beyond its box.
    static func sample(
        _ raster: Raster<Picture.Pixel>,
        _ box: Picture.Renderer.CPU.Box,
        _ x: Double,
        _ y: Double,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
    ) -> Picture.Pixel {
        guard x.isFinite, y.isFinite, box.area > 0 else { return .transparent }
        let point = Point<2, Double>(x: x - Double(box.left), y: y - Double(box.top))
        return raster.sample(at: point, .bilinear, edge: edge) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }

    /// For each pixel of a box, the share of its square inside a path of raster space under a rule.
    static func coverage(
        of path: Picture.Plane.Path,
        rule: Winding.Rule,
        in box: Picture.Renderer.CPU.Box
    ) throws(Picture.Renderer.Error) -> [Float] {
        let moved = path.transformed(by: .translation(Vector([-Double(box.left), -Double(box.top)])))
        do throws(Picture.Plane.Path.Error) {
            return try Raster<Float>.coverage(of: moved, rule: rule, in: box.region, tolerance: .init(Picture.Renderer.CPU.tolerance)).pixels
        } catch {
            throw .path(error)
        }
    }

    /// The box of whole pixels around a path of raster space, one pixel wider on every side.
    static func bounds(of path: Picture.Plane.Path) -> Picture.Renderer.CPU.Box {
        guard let rectangle = path.boundingBox else { return .empty }
        return Picture.Renderer.CPU.Box(rectangle, .identity).expanded(1, 1)
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Draws a picture's elements in order.
    mutating func draw(_ picture: Picture, _ state: Picture.Renderer.CPU.State) throws(Picture.Renderer.Error) {
        for element in picture.elements {
            switch element {
            case .shape(let shape): try draw(shape, state)
            case .sprites(let sprites): draw(sprites, state)
            case .scene(let scene): draw(scene, state)
            case .group(let group): try draw(group, state)
            case .layer(let layer): try draw(layer, state)
            case .pane(let pane): draw(pane, state)
            }
        }
    }

    /// Draws the fill, then the stroke.
    mutating func draw(_ shape: Picture.Shape, _ state: Picture.Renderer.CPU.State) throws(Picture.Renderer.Error) {
        var outline: Picture.Plane.Path?
        if let stroke = shape.stroke {
            let stretch = Picture.Renderer.CPU.stretch(state.transform)
            let tolerance = stretch > 0 && stretch.isFinite ? Picture.Renderer.CPU.tolerance / stretch : Picture.Renderer.CPU.tolerance
            do throws(Picture.Plane.Path.Error) {
                outline = try stroke.outline(of: shape.path, tolerance: .init(tolerance))
            } catch {
                throw .path(error)
            }
        }
        guard let inverse = state.inverse else { return }
        if let fill = shape.fill {
            try paint(shape.path.transformed(by: state.transform), fill.rule, fill.paint, inverse, state)
        }
        if let stroke = shape.stroke, let outline {
            try paint(outline.transformed(by: state.transform), .nonzero, stroke.paint, inverse, state)
        }
    }

    /// Puts a paint over what is behind, at each pixel by the share of it a path of raster space covers.
    mutating func paint(
        _ path: Picture.Plane.Path,
        _ rule: Winding.Rule,
        _ paint: Picture.Paint,
        _ inverse: Picture.Transform,
        _ state: Picture.Renderer.CPU.State
    ) throws(Picture.Renderer.Error) {
        let area = Self.bounds(of: path).intersection(state.reach(in: box))
        guard area.area > 0 else { return }
        let coverage = try Self.coverage(of: path, rule: rule, in: area)
        let map = Picture.Renderer.CPU.Affine(inverse)
        let clip = state.mask
        let width = area.width
        coverage.withUnsafeBufferPointer { coverage in
            unsafe Picture.Renderer.CPU.Mask.reading(clip) { clip in
                @inline(__always)
                func painted(_ source: (_ x: Double, _ y: Double) -> Picture.Pixel) {
                    unsafe rows(area, state.workers) { y, columns, pixels, start in
                        let shares = unsafe clip.row(y)
                        let centre = Double(y) + 0.5
                        var place = (y - area.top) * width + (columns.lowerBound - area.left)
                        var index = start
                        var x = columns.lowerBound
                        while x < columns.upperBound {
                            let share = unsafe coverage[place]
                            if share > 0 {
                                let old = unsafe pixels[index]
                                let pixel = source(Double(x) + 0.5, centre).composited(over: old, coverage: share)
                                unsafe pixels[index] = Picture.Renderer.CPU.limited(old, pixel, unsafe shares.share(x))
                            }
                            x += 1
                            place += 1
                            index += 1
                        }
                    }
                }
                switch paint {
                case .solid(let color):
                    let pixel = color.pixel
                    painted { _, _ in pixel }

                case .linear(let linear):
                    let ramp = Picture.Gradient.Ramp(linear.gradient)
                    let start = (linear.start[0], linear.start[1])
                    let across = linear.end[0] - linear.start[0]
                    let down = linear.end[1] - linear.start[1]
                    let length = across * across + down * down
                    guard length > 0 else {
                        let pixel = ramp.pixel(at: Float(0.0))
                        painted { _, _ in pixel }
                        return
                    }
                    unsafe Picture.Renderer.CPU.Stops.reading(ramp) { stops in
                        painted { x, y in
                            let point = (map.x(x, y), map.y(x, y))
                            return unsafe stops.pixel(at: Float(((point.0 - start.0) * across + (point.1 - start.1) * down) / length))
                        }
                    }

                case .radial(let radial):
                    let ramp = Picture.Gradient.Ramp(radial.gradient)
                    let radius = radial.radius
                    guard radius > 0 else {
                        let pixel = ramp.pixel(at: Float(0.0))
                        painted { _, _ in pixel }
                        return
                    }
                    let centre = (radial.center[0], radial.center[1])
                    unsafe Picture.Renderer.CPU.Stops.reading(ramp) { stops in
                        painted { x, y in
                            let across = map.x(x, y) - centre.0
                            let down = map.y(x, y) - centre.1
                            return unsafe stops.pixel(at: Float((across * across + down * down).squareRoot() / radius))
                        }
                    }

                case .image(let image):
                    let sampler = Picture.Image.Sampler(image)
                    painted { x, y in sampler.pixel(at: map.point(x, y)) }
                }
            }
        }
    }

    /// Draws a group's content under its transform, limited to its clip.
    mutating func draw(_ group: Picture.Group, _ state: Picture.Renderer.CPU.State) throws(Picture.Renderer.Error) {
        var inner = Picture.Renderer.CPU.State(
            transform: state.transform.multiplied(by: group.transform),
            mask: state.mask,
            workers: state.workers,
            beneath: state.beneath
        )
        if let clip = group.clip {
            let path = clip.path.transformed(by: inner.transform)
            let area = Self.bounds(of: path).intersection(state.reach(in: box))
            var values = area.area > 0 ? try Self.coverage(of: path, rule: clip.rule, in: area) : []
            if let outer = state.mask {
                var y = area.top
                while y < area.bottom {
                    var x = area.left
                    while x < area.right {
                        values[area.index(x, y)] *= outer[x, y]
                        x += 1
                    }
                    y += 1
                }
            }
            inner.mask = Picture.Renderer.CPU.Mask(box: area, values: values)
        }
        try draw(group.content, inner)
    }

    /// Draws a layer on a sheet of its own, applies its effects and puts the sheet onto the canvas.
    mutating func draw(_ layer: Picture.Layer, _ state: Picture.Renderer.CPU.State) throws(Picture.Renderer.Error) {
        guard !Picture.Renderer.CPU.Sheet.idle(layer) else { return }
        let target = state.reach(in: box)
        guard target.area > 0 else { return }
        let sheet = try Picture.Renderer.CPU.Sheet(layer, state, target, beneath: [self] + state.beneath).drawn()
        let visit = Picture.Renderer.CPU.Sheet.keeps(layer) ? target.intersection(sheet.box) : target
        let opacity = layer.opacity
        let common = layer.blend == .normal && (layer.operator == .sourceOver || layer.operator == .lighter)
        let lighter = layer.operator == .lighter
        sheet.pixels.withUnsafeBufferPointer { above in
            unsafe Picture.Renderer.CPU.Mask.reading(state.mask) { clip in
                unsafe rows(visit, state.workers) { y, columns, pixels, start in
                    let shares = unsafe clip.row(y)
                    let held = y >= sheet.box.top && y < sheet.box.bottom
                    let first = held ? sheet.box.index(sheet.box.left, y) : 0
                    var index = start
                    var x = columns.lowerBound
                    while x < columns.upperBound {
                        let old = unsafe pixels[index]
                        let pixel = held && x >= sheet.box.left && x < sheet.box.right ? unsafe above[first + x - sheet.box.left] : .transparent
                        let put: Picture.Pixel
                        if common {
                            if lighter {
                                let added = pixel.composited(over: old, operator: .lighter, blend: .normal, coverage: opacity)
                                put = added.alpha > 1 ? Picture.Pixel(color: added.color, alpha: 1) : added
                            } else {
                                put = pixel.composited(over: old, operator: .sourceOver, blend: .normal, coverage: opacity)
                            }
                        } else {
                            put = layer.composited(pixel, over: old)
                        }
                        unsafe pixels[index] = Picture.Renderer.CPU.limited(old, put, unsafe shares.share(x))
                        x += 1
                        index += 1
                    }
                }
            }
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// The picture as it stands under what is drawn next, over a box: this canvas put with `sourceOver` onto the
    /// canvases beneath it, each onto the next, as if every layer it stands in ended here at full strength and
    /// without its effects. On the raster itself that is the canvas; glass reads it, so that glass in a layer
    /// shows what lies beneath the layer and the layer's opacity fades the glass's result, not its backdrop.
    /// The box is cut to the outermost canvas's.
    func seen(over area: Picture.Renderer.CPU.Box, _ state: Picture.Renderer.CPU.State) -> Self {
        guard let outermost = state.beneath.last else { return self }
        let area = area.intersection(outermost.box)
        let beneath = state.beneath
        let top = self
        return Self(area, state.workers) { x, y in
            let (column, row) = (Int(x.rounded(.down)), Int(y.rounded(.down)))
            var pixel = outermost[column, row]
            var index = beneath.count - 2
            while index >= 0 {
                pixel = beneath[index][column, row].composited(over: pixel)
                index -= 1
            }
            return top[column, row].composited(over: pixel)
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// A box of raster space outside which a picture under a transform leaves its sheet transparent,
    /// or nil when no such box is known.
    static func bounds(of picture: Picture, _ transform: Picture.Transform) -> Picture.Renderer.CPU.Box? {
        var total = Picture.Renderer.CPU.Box.empty
        for element in picture.elements {
            guard let box = bounds(of: element, transform) else { return nil }
            total = total.union(box)
        }
        return total
    }

    /// A box of raster space outside which one element under a transform draws nothing, or nil.
    static func bounds(of element: Picture.Element, _ transform: Picture.Transform) -> Picture.Renderer.CPU.Box? {
        switch element {
        case .shape(let shape):
            guard let rectangle = shape.path.boundingBox else { return .empty }
            var reach = 0.0
            if let pen = shape.stroke?.pen {
                var factor = pen.cap == .square ? 2.0.squareRoot() : 1
                if case .miter(let limit) = pen.join { factor = Swift.max(factor, limit.value) }
                reach = pen.width.underlying / 2 * factor
            }
            guard reach.isFinite else { return nil }
            let grown = Picture.Plane.Rectangle(
                llx: .init(rectangle.llx.underlying - reach),
                lly: .init(rectangle.lly.underlying - reach),
                urx: .init(rectangle.urx.underlying + reach),
                ury: .init(rectangle.ury.underlying + reach)
            )
            return Picture.Renderer.CPU.Box(grown, transform).expanded(1, 1)

        case .sprites(let sprites):
            var total = Picture.Renderer.CPU.Box.empty
            for sprite in sprites.sprites where sprite.radius > 0 {
                let square = Picture.Plane.Rectangle(
                    llx: .init(sprite.center[0] - sprite.radius),
                    lly: .init(sprite.center[1] - sprite.radius),
                    urx: .init(sprite.center[0] + sprite.radius),
                    ury: .init(sprite.center[1] + sprite.radius)
                )
                total = total.union(Picture.Renderer.CPU.Box(square, transform).expanded(1, 1))
            }
            return total

        case .scene:
            return nil

        case .pane(let pane):
            return Picture.Renderer.CPU.Slab.bounds(of: pane, transform)

        case .group(let group):
            let inner = transform.multiplied(by: group.transform)
            let content = bounds(of: group.content, inner)
            guard let clip = group.clip else { return content }
            let around = bounds(of: clip.path.transformed(by: inner))
            return content.map { $0.intersection(around) } ?? around

        case .layer(let layer):
            let steps: [Picture.Renderer.CPU.Step]?
            do throws(Picture.Renderer.Error) {
                steps = try Picture.Renderer.CPU.Sheet.steps(layer, transform)
            } catch {
                return nil
            }
            guard let steps else { return .empty }
            var box = bounds(of: layer.content, transform)
            for step in steps { box = step.support(box) }
            return box
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Draws a pane: its glass's shadows over what is behind, then over the region the glass's pixel of the
    /// picture as it stood before the shadows, read through the pane. Pixels on the boundary and under the light's
    /// line take the mean of 3 × 3 points and those in the outer two fifths of the rim, where the bend changes
    /// fast, of 2 × 2; a point outside the region keeps what was there.
    mutating func draw(_ pane: Picture.Glass.Pane, _ state: Picture.Renderer.CPU.State) {
        guard let inverse = state.inverse else { return }
        let transform = state.transform
        let determinant = abs(transform.linear.determinant)
        let scale = determinant.squareRoot()
        guard scale > 0, scale.isFinite, let rectangle = pane.region.boundingBox else { return }
        let reach = state.reach(in: box)
        let inside = Picture.Renderer.CPU.Box(rectangle, transform).expanded(1, 1).intersection(reach)
        let margin = Int((Picture.Renderer.CPU.Slab.reach(of: pane, scale: scale) * scale).rounded(.up)) + 2
        let spread = margin + Int(Swift.min(4 * Swift.max(pane.glass.frost, 0) * scale, 4096).rounded(.up))
        let before = inside.area > 0 ? seen(over: inside.expanded(spread, spread), state) : self
        let region = pane.region
        let outer = Picture.Renderer.CPU.Slab.bounds(of: pane, transform).intersection(reach)
        let coarse = Picture.Renderer.CPU.Slab.Coarse(region, over: outer, inverse, scale: scale)

        for shadow in pane.shadows where shadow.color.alpha > 0 {
            let area = outer
            let color = shadow.color.with(alpha: 1).pixel
            let strength = shadow.color.alpha
            let shift = (abs(shadow.offset[0]) + abs(shadow.offset[1])) * scale
            let far = 8 * Swift.max(shadow.softness, 0) * scale
            update(
                area,
                state.workers,
                making: {
                    let region = Picture.Renderer.CPU.Slab.unshared(region)
                    return { x, y, old in
                        let bound = coarse.bound(x, y)
                        // Deep inside the pane, which covers it, or so far out that the shadow there is below 1/2000.
                        guard bound.upper > -(shift + 1.5), bound.lower < shift + far + 1 else { return old }
                        let point = Picture.Renderer.CPU.point(inverse, Double(x) + 0.5, Double(y) + 0.5)
                        let moved = Picture.Plane.Point<2>([point[0] - shadow.offset[0], point[1] - shadow.offset[1]])
                        let share = Float(shadow.share(at: region.distance(to: moved))) * strength
                        guard share > 0 else { return old }
                        return Picture.Renderer.CPU.limited(old, color.composited(over: old, coverage: share), state.share(x, y))
                    }
                }
            )
        }
        guard inside.area > 0 else { return }

        let deviation = pane.glass.frost * scale
        let frost = Picture.Renderer.CPU.Frost(before, over: inside.expanded(margin, margin).intersection(before.box), deviation: deviation, state.workers)
        let shading = Picture.Glass.Shading(pane.glass, surroundings: pane.surroundings)
        let linear = (transform[0, 0], transform[0, 1], transform[1, 0], transform[1, 1])
        let rimPixels = pane.rim * scale

        let body = pane.glass.body
        let indices = body.map(Picture.Renderer.CPU.Spectra.Indices.init)
        let tilts = body?.tilts ?? [1, 1, 1]

        func glass(_ pane: Picture.Glass.Pane, _ x: Double, _ y: Double, _ sample: Picture.Plane.Region.Sample) -> Picture.Pixel {
            let passage = Picture.Glass.Pane.Passage(through: pane, for: sample)
            let outline = Picture.Glass.Outline(inward: -sample.distance, outward: Vector([sample.gradient[0], -sample.gradient[1]]))
            let frosting = Picture.Glass.frosting(facing: passage.normal)
            func place(_ offset: Vector<2, Double>) -> (x: Double, y: Double) {
                (x + linear.0 * offset[0] + linear.1 * offset[1], y + linear.2 * offset[0] + linear.3 * offset[1])
            }
            let read: Picture.Pixel
            if let indices, passage.body, passage.normal[2] < 1 {
                read = Picture.Renderer.CPU.Spectra.pixel(indices, read: { place(passage.offset(for: $0)) }) {
                    frost.read($0, $1, frosting: frosting)
                }
            } else {
                let at = place(passage.offset)
                read = frost.read(at.x, at.y, frosting: frosting)
            }
            return shading.pixel(
                over: Picture.Renderer.CPU.Spectra.joined(read),
                through: 1,
                leaving: passage.leaving,
                beyond: 0,
                mirroring: passage.mirrored,
                by: passage.share,
                facing: passage.normal,
                outline: outline,
                tilts: tilts
            )
        }

        let level = Picture.Glass.Pane.Passage(through: pane, for: .init(distance: -.infinity, gradient: .zero))
        let lineBand = 2.5 * Swift.max(pane.glass.light?.width ?? 0, 0) * scale
        let rimDepth = Swift.max(rimPixels, lineBand) + 1.5

        update(
            inside,
            state.workers,
            making: {
                var pane = pane
                pane.region = Picture.Renderer.CPU.Slab.unshared(region)
                let region = pane.region
                return { x, y, old in
                    let bound = coarse.bound(x, y)
                    guard bound.lower < 1.5 else { return old }
                    let cx = Double(x) + 0.5
                    let cy = Double(y) + 0.5
                    if bound.upper < -rimDepth {
                        let read = frost.read(cx, cy)
                        let pixel = shading.pixel(
                            over: Picture.Renderer.CPU.Spectra.joined(read),
                            through: 1,
                            leaving: level.leaving,
                            beyond: 0,
                            mirroring: level.mirrored,
                            by: level.share,
                            facing: level.normal
                        )
                        return Picture.Renderer.CPU.limited(old, pixel, state.share(x, y))
                    }
                    let centre = region.sample(at: Picture.Renderer.CPU.point(inverse, cx, cy))
                    let depth = -centre.distance * scale
                    guard depth > -1.5 else { return old }
                    let samples = depth < Swift.max(1.5, lineBand + 0.5) ? 3 : (depth < rimPixels * 0.4 ? 2 : 1)
                    guard samples > 1 else { return Picture.Renderer.CPU.limited(old, glass(pane, cx, cy, centre), state.share(x, y)) }
                    var sum = SIMD4<Float>.zero
                    var first = old
                    var uniform = true
                    var count = 0
                    var row = 0
                    while row < samples {
                        var column = 0
                        while column < samples {
                            let sx = Double(x) + (Double(column) + 0.5) / Double(samples)
                            let sy = Double(y) + (Double(row) + 0.5) / Double(samples)
                            let sample = region.sample(at: Picture.Renderer.CPU.point(inverse, sx, sy))
                            let value = sample.distance > 0 ? old : glass(pane, sx, sy, sample)
                            sum += Picture.Renderer.CPU.components(value)
                            if count == 0 { first = value } else { uniform = uniform && value == first }
                            count += 1
                            column += 1
                        }
                        row += 1
                    }
                    let pixel = uniform ? first : Picture.Renderer.CPU.mean(sum, of: count)
                    return Picture.Renderer.CPU.limited(old, pixel, state.share(x, y))
                }
            }
        )
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Adds the sprites' light to what is behind, read at each pixel's centre, by `Picture.Sprites.composited(_:over:)`.
    mutating func draw(_ sprites: Picture.Sprites, _ state: Picture.Renderer.CPU.State) {
        guard let inverse = state.inverse else { return }
        let tiles = Picture.Renderer.CPU.Tiles(sprites, state.transform, over: state.reach(in: box))
        let map = Picture.Renderer.CPU.Affine(inverse)
        let profile = sprites.profile
        let box = self.box
        unsafe Picture.Renderer.CPU.Mask.reading(state.mask) { clip in
            pixels.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
                state.workers.run(tiles.lists.count) { position in
                    tiles.lists[position].withUnsafeBufferPointer { list in
                        guard !list.isEmpty else { return }
                        let tile = tiles.tile(position)
                        var y = tile.top
                        while y < tile.bottom {
                            let shares = unsafe clip.row(y)
                            let centre = Double(y) + 0.5
                            var x = tile.left
                            while x < tile.right {
                                let across = Double(x) + 0.5
                                let light = unsafe Picture.Renderer.CPU.Tiles.light(list, profile, at: map.x(across, centre), map.y(across, centre))
                                if light != .transparent {
                                    let index = box.index(x, y)
                                    let old = unsafe shared[index]
                                    unsafe shared[index] = Picture.Renderer.CPU.limited(old, Picture.Sprites.composited(light, over: old), unsafe shares.share(x))
                                }
                                x += 1
                            }
                            y += 1
                        }
                    }
                }
            }
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Draws a scene straight onto what is behind. Each pixel takes the mean of `samples` × `samples` points,
    /// each showing the nearest surface there over what was behind; then glass, over the picture as it stood
    /// after every other model, read at the point plus the glass's offset.
    mutating func draw(_ scene: Picture.Scene, _ state: Picture.Renderer.CPU.State) {
        let samples = Picture.Renderer.CPU.samples
        let stage = Picture.Renderer.CPU.Stage(scene, state.transform, samples: samples)
        let area = stage.bounds.intersection(state.reach(in: box))
        guard area.area > 0 else { return }
        let upper = scene.camera.projection.depth.range.upperBound
        let haze = scene.haze.map { haze in (haze: haze, pixel: haze.color.pixel, camera: scene.camera) }
        let opaque = Picture.Renderer.CPU.Stage.tiles(stage.opaque, over: area)
        // A shaded triangle's colour changes across it, so where a scene has one its points are weighed on corners.
        let shaded = stage.lights.contains { $0 != nil }
        unsafe tiles(opaque.count, state.workers) { shared, box, part in
            let (tile, numbers) = opaque[part]
            guard !numbers.isEmpty else { return }
            let weighed = shaded ? Picture.Renderer.CPU.Stage.hits(stage.opaque, numbers, in: tile, samples: samples) : []
            let hits =
                shaded
                ? weighed.map { Picture.Renderer.CPU.Hit.Nearest(triangle: $0.triangle, depth: $0.depth) }
                : Picture.Renderer.CPU.Stage.nearest(stage.opaque, numbers, in: tile, samples: samples)
            unsafe Self.visit(shared, box, tile, samples) { row, column in
                let hit = hits[row * tile.width * samples + column]
                return hit.triangle >= 0 && hit.depth <= upper
            } value: { _, _, row, column, old in
                let position = row * tile.width * samples + column
                let hit = hits[position]
                var color = stage.colors[hit.triangle]
                if shaded, let light = stage.lights[hit.triangle] { color = light.pixel(weighed[position].weights, stage.ramps[light.ramp]) }
                guard let haze else { return color.composited(over: old) }
                let share = haze.haze.share(at: haze.camera.distance(at: hit.depth) ?? .infinity)
                guard share > 0 else { return color.composited(over: old) }
                return color.interpolated(to: haze.pixel, at: Float(share)).composited(over: old)
            } finish: { x, y, old, mean in
                Picture.Renderer.CPU.limited(old, mean, state.share(x, y))
            }
        }
        guard !stage.glass.isEmpty else { return }
        let scale = abs(state.transform.linear.determinant).squareRoot()
        // The picture behind is read around the scene, as far again as the scene is wide or tall; past that a
        // read finds the nearest pixel kept.
        let frosted = Int(Swift.min(4 * (stage.surfaces.map { Swift.max($0.glass.frost, 0) }.max() ?? 0) * scale, 4096).rounded(.up))
        let reach = Swift.max(area.width, area.height) / 2 + frosted
        let before = seen(over: area.expanded(reach, reach), state)
        let around = area.expanded(Swift.max(area.width, area.height) / 2, Swift.max(area.width, area.height) / 2).intersection(before.box)
        var levels: [Double] = []
        var frosts: [Picture.Renderer.CPU.Frost] = []
        var frostOf = [Int](repeating: -1, count: scene.models.count)
        for surface in stage.surfaces where frostOf[surface.model] < 0 {
            let level = surface.glass.frost
            if let known = levels.firstIndex(of: level) {
                frostOf[surface.model] = known
            } else if !level.isNaN {
                frostOf[surface.model] = frosts.count
                levels.append(level)
                frosts.append(Picture.Renderer.CPU.Frost(before, over: around, deviation: level * scale, state.workers))
            }
        }
        let glass = Picture.Renderer.CPU.Stage.tiles(stage.glass, over: area)
        let eyes = scene.models.map { scene.camera.eye(of: $0.transform) }
        let shadows = scene.shadows
        let lined = stage.surfaces.contains { ($0.glass.light?.line ?? 0) > 0 && ($0.glass.light?.width ?? 0) > 0 }
        var reachOfShadows = 0.0
        for shadow in shadows {
            reachOfShadows = Swift.max(reachOfShadows, (abs(shadow.offset[0]) + abs(shadow.offset[1]) + 4 * Swift.max(shadow.softness, 0)) * scale)
        }
        let outlined =
            shadows.isEmpty && !lined
            ? nil
            : Self.silhouette(
                stage,
                glass: glass,
                opaque: opaque,
                over: area.expanded(Int(reachOfShadows) + 2, Int(reachOfShadows) + 2).intersection(state.reach(in: box)),
                upper: upper,
                state.workers
            )
        if let outlined {
            for shadow in shadows where shadow.color.alpha > 0 {
                let color = shadow.color.with(alpha: 1).pixel
                let strength = shadow.color.alpha
                let across = state.transform[0, 0] * shadow.offset[0] + state.transform[0, 1] * shadow.offset[1]
                let down = state.transform[1, 0] * shadow.offset[0] + state.transform[1, 1] * shadow.offset[1]
                update(outlined.box, state.workers) { x, y, old in
                    let distance = outlined.distance(Double(x) + 0.5 - across, Double(y) + 0.5 - down)
                    guard distance.isFinite else { return old }
                    let share = Float(shadow.share(at: distance / scale)) * strength
                    guard share > 0 else { return old }
                    return Picture.Renderer.CPU.limited(old, color.composited(over: old, coverage: share), state.share(x, y))
                }
            }
        }
        let glasses = scene.models.map { model -> Picture.Glass? in
            if case .glass(let glass, _) = model.material { return glass }
            return nil
        }
        let shadings = glasses.map { Picture.Glass.Shading($0 ?? Picture.Glass(), surroundings: scene.surroundings) }
        let tilts = glasses.map { $0?.body?.tilts ?? [1, 1, 1] }
        let bodies = glasses.map { $0?.body }
        let indices = glasses.map { $0?.body.map(Picture.Renderer.CPU.Spectra.Indices.init) }
        let corners = stage.surfaces.map(\.corners)
        let models = stage.surfaces.map(\.model)
        let linear = Picture.Renderer.CPU.Affine(state.transform)
        let lens = Picture.Renderer.CPU.Lens(scene, state.transform)
        let far = Picture.Renderer.CPU.Far(stage, eyes: eyes, over: area)
        let measures = zip(scene.models, eyes).map { model, eye in Picture.Renderer.CPU.Body(model, eye: eye, lens: lens, scale: scale) }
        unsafe tiles(glass.count, state.workers) { shared, box, part in
            let (tile, numbers) = glass[part]
            let covers = opaque[part].triangles
            guard !numbers.isEmpty else { return }
            let hits = Picture.Renderer.CPU.Stage.hits(stage.glass, numbers, in: tile, samples: samples)
            let nearest = Picture.Renderer.CPU.Stage.nearest(stage.opaque, covers, in: tile, samples: samples)
            unsafe Self.visit(shared, box, tile, samples, thin: true) { row, column in
                let position = row * tile.width * samples + column
                let hit = hits[position]
                let cover = nearest[position]
                let hidden = cover.triangle >= 0 && cover.depth <= upper && cover.depth <= hit.depth
                return hit.triangle >= 0 && hit.depth <= upper && !hidden
            } value: { x, y, row, column, old in
                let hit = hits[row * tile.width * samples + column]
                let model = models[hit.triangle]
                let surface = corners[hit.triangle]
                let normal = Picture.Scene.Camera.direction(surface.normal(hit.weights), through: eyes[model])
                let shading = shadings[model]
                let level = frostOf[model]
                let frosting = Picture.Glass.frosting(facing: normal)
                let sampleX = Double(x) + (Double(column % samples) + 0.5) / Double(samples)
                let sampleY = Double(y) + (Double(row % samples) + 0.5) / Double(samples)
                var outline: Picture.Glass.Outline?
                if let outlined {
                    let across = (normal[0] * normal[0] + normal[1] * normal[1]).squareRoot()
                    let inward = -outlined.distance(sampleX, sampleY) / scale
                    if inward.isFinite {
                        outline = Picture.Glass.Outline(
                            inward: Swift.max(inward, 0),
                            outward: Vector([across > 0 ? normal[0] / across : 0, across > 0 ? normal[1] / across : 0])
                        )
                    }
                }
                func read(_ x: Double, _ y: Double) -> Picture.Pixel {
                    level >= 0 ? frosts[level].read(x, y, frosting: frosting) : .transparent
                }
                if let body = bodies[model], let spectra = indices[model] {
                    let passage = Picture.Renderer.CPU.Traversal(
                        from: surface.place(hit.weights),
                        normal: normal,
                        at: .init(x: sampleX, y: sampleY),
                        through: body,
                        surroundings: scene.surroundings,
                        plane: measures[model]?.plane ?? -.infinity,
                        lens: lens,
                        far: far
                    )
                    let behind = Picture.Renderer.CPU.Spectra.pixel(
                        spectra,
                        read: { index in
                            let at = passage.read(for: index, lens: lens)
                            return (at.x, at.y)
                        }
                    ) { read($0, $1) }
                    return shading.pixel(
                        over: Picture.Renderer.CPU.Spectra.joined(behind),
                        through: passage.length / (measures[model]?.thickness ?? 1),
                        leaving: passage.leaving,
                        beyond: passage.beyond,
                        mirroring: passage.mirrored,
                        by: passage.share,
                        facing: normal,
                        outline: outline,
                        tilts: tilts[model]
                    )
                }
                let offset = glasses[model]?.offset(for: normal) ?? .zero
                let across = linear.xx * offset[0] + linear.xy * offset[1]
                let down = linear.yx * offset[0] + linear.yy * offset[1]
                let point = (
                    x: Double(x) + (Double(column % samples) + 0.5) / Double(samples) + across,
                    y: Double(y) + (Double(row % samples) + 0.5) / Double(samples) + down
                )
                return shading.pixel(over: read(point.x, point.y), facing: normal, outline: outline)
            } finish: { x, y, old, mean in
                Picture.Renderer.CPU.limited(old, mean, state.share(x, y))
            }
        }
    }

    /// For each pixel of a tile, the mean over its `samples` × `samples` points of what `value` gives for the
    /// pixel as it is at a point that is `taken`, and of the pixel as it is at one that is not (row and column
    /// count sample points from the tile's corner), put in place by `finish`. A pixel none of whose points is
    /// taken is left alone and never read, as is one all of whose points give it back unchanged. When `thin`,
    /// a pixel all of whose points are taken takes the mean of only its central half along each side, a quarter
    /// of them and centred on the pixel's centre, since inside a surface what changes across a pixel is smooth;
    /// a pixel on an edge keeps every point.
    /// Whether a sample point along one side of a pixel lies in the pixel's central half.
    static func central(_ index: Int, _ samples: Int) -> Bool {
        let place = index % samples
        return place >= samples / 4 && place < samples - samples / 4
    }

    static func visit(
        _ pixels: Picture.Renderer.CPU.Workers.Pixels,
        _ box: Picture.Renderer.CPU.Box,
        _ tile: Picture.Renderer.CPU.Box,
        _ samples: Int,
        thin: Bool = false,
        taken: (_ row: Int, _ column: Int) -> Bool,
        value: (_ x: Int, _ y: Int, _ row: Int, _ column: Int, _ old: Picture.Pixel) -> Picture.Pixel,
        finish: (_ x: Int, _ y: Int, _ old: Picture.Pixel, _ mean: Picture.Pixel) -> Picture.Pixel
    ) {
        var y = tile.top
        while y < tile.bottom {
            var x = tile.left
            while x < tile.right {
                var any = false
                var all = true
                var point = 0
                while point < samples * samples, !any || (thin && all) {
                    let hit = taken((y - tile.top) * samples + point / samples, (x - tile.left) * samples + point % samples)
                    any = any || hit
                    all = all && hit
                    point += 1
                }
                let sparse = thin && all && samples >= 2
                guard any else {
                    x += 1
                    continue
                }
                let index = box.index(x, y)
                let old = unsafe pixels[index]
                var sum = SIMD4<Float>.zero
                var first = old
                var uniform = true
                var changed = false
                var count = 0
                var row = (y - tile.top) * samples
                while row < (y - tile.top + 1) * samples {
                    var column = (x - tile.left) * samples
                    while column < (x - tile.left + 1) * samples {
                        if sparse, !Self.central(row, samples) || !Self.central(column, samples) {
                            column += 1
                            continue
                        }
                        let sample = taken(row, column) ? value(x, y, row, column, old) : old
                        changed = changed || sample != old
                        sum += Picture.Renderer.CPU.components(sample)
                        if count == 0 { first = sample } else { uniform = uniform && sample == first }
                        count += 1
                        column += 1
                    }
                    row += 1
                }
                if changed { unsafe pixels[index] = finish(x, y, old, uniform ? first : Picture.Renderer.CPU.mean(sum, of: count)) }
                x += 1
            }
            y += 1
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Calls `body` for each of some tiles of the canvas on the workers, with the canvas's pixels and box;
    /// each call writes only the pixels of its own tile.
    mutating func tiles(
        _ count: Int,
        _ workers: Picture.Renderer.CPU.Workers,
        _ body: (_ pixels: Picture.Renderer.CPU.Workers.Pixels, _ box: Picture.Renderer.CPU.Box, _ part: Int) -> Void
    ) {
        let box = self.box
        pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
            workers.run(count) { part in unsafe body(shared, box, part) }
        }
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// The outline of a scene's glass as drawn over a box: at the silhouette's fine points, whether the nearest
    /// glass is nearer than every opaque model there and within the far plane, and from that the signed distance.
    static func silhouette(
        _ stage: Picture.Renderer.CPU.Stage,
        glass: [(tile: Picture.Renderer.CPU.Box, triangles: [Int])],
        opaque: [(tile: Picture.Renderer.CPU.Box, triangles: [Int])],
        over box: Picture.Renderer.CPU.Box,
        upper: Double,
        _ workers: Picture.Renderer.CPU.Workers
    ) -> Picture.Renderer.CPU.Silhouette {
        let fine = Picture.Renderer.CPU.Silhouette.fine
        let columns = box.width * fine
        var inside = [Bool](repeating: false, count: columns * box.height * fine)
        let parts = Mutex([[Bool]?](repeating: nil, count: glass.count))
        workers.run(glass.count) { part in
            let (tile, numbers) = glass[part]
            guard !numbers.isEmpty, tile.intersection(box).area > 0 else { return }
            let hits = Picture.Renderer.CPU.Stage.nearest(stage.glass, numbers, in: tile, samples: fine)
            let covers = Picture.Renderer.CPU.Stage.nearest(stage.opaque, opaque[part].triangles, in: tile, samples: fine)
            let taken = zip(hits, covers).map { hit, cover in
                let hidden = cover.triangle >= 0 && cover.depth <= upper && cover.depth <= hit.depth
                return hit.triangle >= 0 && hit.depth <= upper && !hidden
            }
            parts.withLock { $0[part] = taken }
        }
        let found = parts.withLock { $0 }
        for (part, taken) in zip(found.indices, found) {
            guard let taken else { continue }
            let tile = glass[part].tile
            let width = tile.width * fine
            for (position, value) in zip(taken.indices, taken) where value {
                let x = (tile.left - box.left) * fine + position % width
                let y = (tile.top - box.top) * fine + position / width
                guard x >= 0, y >= 0, x < columns, y < box.height * fine else { continue }
                inside[y * columns + x] = true
            }
        }
        return Picture.Renderer.CPU.Silhouette(box, inside: inside, workers)
    }
}
