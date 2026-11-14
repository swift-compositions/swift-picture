import Picture

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
        // The paint is read the way its kind reads it, the kind chosen once for the whole area and not per
        // pixel; each reads exactly as `Picture.Paint.pixel(at:)` does at the pixel's centre.
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
                    let ramp = linear.gradient.ramp
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
                    let ramp = radial.gradient.ramp
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
                    let sampler = image.sampler
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
                            // `Picture.Layer.composited(_:over:)` with its operator and blend mode known.
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
