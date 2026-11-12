import Picture

extension Picture.Renderer.CPU {
    /// Working pixels over a box of raster space: the raster itself, or a layer's sheet.
    struct Canvas {
        var box: Box
        var pixels: [Picture.Pixel]
    }
}

extension Picture.Renderer.CPU.Canvas {
    typealias CPU = Picture.Renderer.CPU

    /// A canvas over a box, every pixel the same.
    init(_ box: CPU.Box, repeating pixel: Picture.Pixel) {
        self.init(box: box, pixels: [Picture.Pixel](repeating: pixel, count: box.area))
    }

    /// A canvas holding a raster's pixels at the raster's own place.
    init(_ raster: Raster<Picture.Pixel>) {
        self.init(
            box: CPU.Box(left: 0, top: 0, right: Int(clamping: raster.width), bottom: Int(clamping: raster.height)),
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

    /// A canvas over a box whose pixels are a function of their centres in raster space.
    init(_ box: CPU.Box, _ pixel: (_ x: Double, _ y: Double) -> Picture.Pixel) {
        var pixels: [Picture.Pixel] = []
        pixels.reserveCapacity(box.area)
        var y = box.top
        while y < box.bottom {
            var x = box.left
            while x < box.right {
                pixels.append(pixel(Double(x) + 0.5, Double(y) + 0.5))
                x += 1
            }
            y += 1
        }
        self.init(box: box, pixels: pixels)
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
    static func sample(_ raster: Raster<Picture.Pixel>, _ box: CPU.Box, _ x: Double, _ y: Double) -> Picture.Pixel {
        guard x.isFinite, y.isFinite, box.area > 0 else { return .transparent }
        let point = Point<2, Double>(x: x - Double(box.left), y: y - Double(box.top))
        return raster.sample(at: point, .bilinear, edge: .constant(.transparent)) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }

    /// For each pixel of a box, the share of its square inside a path of raster space under a rule.
    static func coverage(
        of path: Picture.Plane.Path,
        rule: Winding.Rule,
        in box: CPU.Box
    ) throws(Picture.Renderer.Error) -> [Float] {
        let moved = path.transformed(by: .translation(Vector([-Double(box.left), -Double(box.top)])))
        do throws(Picture.Plane.Path.Error) {
            return try Raster<Float>.coverage(of: moved, rule: rule, in: box.region, tolerance: .init(CPU.tolerance)).pixels
        } catch {
            throw .path(error)
        }
    }

    /// The box of whole pixels around a path of raster space, one pixel wider on every side.
    static func bounds(of path: Picture.Plane.Path) -> CPU.Box {
        guard let rectangle = path.boundingBox else { return .empty }
        return CPU.Box(rectangle, .identity).expanded(1, 1)
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Draws a picture's elements in order.
    mutating func draw(_ picture: Picture, _ state: CPU.State) throws(Picture.Renderer.Error) {
        for element in picture.elements {
            switch element {
            case .shape(let shape): try draw(shape, state)
            case .sprites(let sprites): try draw(sprites, state)
            case .scene(let scene): try draw(scene, state)
            case .group(let group): try draw(group, state)
            case .layer(let layer): try draw(layer, state)
            }
        }
    }

    /// Draws the fill, then the stroke.
    mutating func draw(_ shape: Picture.Shape, _ state: CPU.State) throws(Picture.Renderer.Error) {
        var outline: Picture.Plane.Path?
        if let stroke = shape.stroke {
            let stretch = CPU.stretch(state.transform)
            let tolerance = stretch > 0 && stretch.isFinite ? CPU.tolerance / stretch : CPU.tolerance
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
        _ state: CPU.State
    ) throws(Picture.Renderer.Error) {
        let area = Self.bounds(of: path).intersection(state.reach(in: box))
        guard area.area > 0 else { return }
        let coverage = try Self.coverage(of: path, rule: rule, in: area)
        var solid: Picture.Pixel?
        if case .solid = paint { solid = paint.pixel(at: .zero) }
        var y = area.top
        while y < area.bottom {
            var x = area.left
            while x < area.right {
                let share = coverage[area.index(x, y)]
                if share > 0 {
                    let source = solid ?? paint.pixel(at: CPU.point(inverse, Double(x) + 0.5, Double(y) + 0.5))
                    let index = box.index(x, y)
                    let old = pixels[index]
                    pixels[index] = CPU.limited(old, source.composited(over: old, coverage: share), state.share(x, y))
                }
                x += 1
            }
            y += 1
        }
    }

    /// Draws a group's content under its transform, limited to its clip.
    mutating func draw(_ group: Picture.Group, _ state: CPU.State) throws(Picture.Renderer.Error) {
        var inner = CPU.State(transform: state.transform.multiplied(by: group.transform), mask: state.mask)
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
            inner.mask = CPU.Mask(box: area, values: values)
        }
        try draw(group.content, inner)
    }

    /// Draws a layer on a sheet of its own, applies its effects and puts the sheet onto the canvas.
    mutating func draw(_ layer: Picture.Layer, _ state: CPU.State) throws(Picture.Renderer.Error) {
        let target = state.reach(in: box)
        guard target.area > 0 else { return }
        let sheet = try CPU.Sheet(layer, state, target).drawn()
        let visit = CPU.Sheet.keeps(layer) ? target.intersection(sheet.box) : target
        var y = visit.top
        while y < visit.bottom {
            var x = visit.left
            while x < visit.right {
                let index = box.index(x, y)
                let old = pixels[index]
                pixels[index] = CPU.limited(old, layer.composited(sheet[x, y], over: old), state.share(x, y))
                x += 1
            }
            y += 1
        }
    }

    /// Sprites are not drawn yet.
    mutating func draw(_ sprites: Picture.Sprites, _ state: CPU.State) throws(Picture.Renderer.Error) {
        throw .unsupported
    }

    /// Scenes are not drawn yet.
    mutating func draw(_ scene: Picture.Scene, _ state: CPU.State) throws(Picture.Renderer.Error) {
        throw .unsupported
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// A box of raster space outside which a picture under a transform leaves its sheet transparent,
    /// or nil when no such box is known.
    static func bounds(of picture: Picture, _ transform: Picture.Transform) -> CPU.Box? {
        var total = CPU.Box.empty
        for element in picture.elements {
            guard let box = bounds(of: element, transform) else { return nil }
            total = total.union(box)
        }
        return total
    }

    /// A box of raster space outside which one element under a transform draws nothing, or nil.
    static func bounds(of element: Picture.Element, _ transform: Picture.Transform) -> CPU.Box? {
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
            return CPU.Box(grown, transform).expanded(1, 1)

        case .sprites(let sprites):
            var total = CPU.Box.empty
            for sprite in sprites.sprites where sprite.radius > 0 {
                let square = Picture.Plane.Rectangle(
                    llx: .init(sprite.center[0] - sprite.radius),
                    lly: .init(sprite.center[1] - sprite.radius),
                    urx: .init(sprite.center[0] + sprite.radius),
                    ury: .init(sprite.center[1] + sprite.radius)
                )
                total = total.union(CPU.Box(square, transform).expanded(1, 1))
            }
            return total

        case .scene:
            return nil

        case .group(let group):
            let inner = transform.multiplied(by: group.transform)
            let content = bounds(of: group.content, inner)
            guard let clip = group.clip else { return content }
            let around = bounds(of: clip.path.transformed(by: inner))
            return content.map { $0.intersection(around) } ?? around

        case .layer(let layer):
            guard layer.effects.isEmpty else { return nil }
            return bounds(of: layer.content, transform)
        }
    }
}
