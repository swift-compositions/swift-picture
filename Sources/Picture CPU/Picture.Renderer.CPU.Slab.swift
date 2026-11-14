import Picture

extension Picture.Renderer.CPU {
    /// How a pane of glass is drawn.
    enum Slab {}
}

extension Picture.Renderer.CPU.Slab {
    /// The box of raster space outside which a pane under a transform draws nothing: its region's, grown by its
    /// shadows' offsets and four times their softness, and a pixel.
    static func bounds(of pane: Picture.Glass.Pane, _ transform: Picture.Transform) -> Picture.Renderer.CPU.Box {
        guard let rectangle = pane.region.boundingBox else { return .empty }
        var reach = 0.0
        for shadow in pane.glass.shadows {
            reach = Swift.max(reach, abs(shadow.x) + abs(shadow.y) + 4 * Swift.max(shadow.softness, 0))
        }
        guard reach.isFinite else { return .empty }
        let grown = Picture.Plane.Rectangle(
            llx: .init(rectangle.llx.underlying - reach),
            lly: .init(rectangle.lly.underlying - reach),
            urx: .init(rectangle.urx.underlying + reach),
            ury: .init(rectangle.ury.underlying + reach)
        )
        return Picture.Renderer.CPU.Box(grown, transform).expanded(1, 1)
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

        for shadow in pane.glass.shadows where shadow.color.alpha > 0 {
            let area = outer
            let color = shadow.color.with(alpha: 1).pixel
            let strength = shadow.color.alpha
            let shift = (abs(shadow.x) + abs(shadow.y)) * scale
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
                        let moved = Picture.Plane.Point<2>([point[0] - shadow.x, point[1] - shadow.y])
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
        let shading = pane.glass.shading
        let linear = (transform[0, 0], transform[0, 1], transform[1, 0], transform[1, 1])
        let rimPixels = pane.rim * scale

        let refraction = pane.glass.refraction
        let indices = refraction.map(Picture.Renderer.CPU.Spectra.Indices.init)
        let tilts = refraction?.tilts ?? [1, 1, 1]

        func glass(_ pane: Picture.Glass.Pane, _ x: Double, _ y: Double, _ sample: Picture.Plane.Region.Sample) -> Picture.Pixel {
            let passage = Picture.Glass.Pane.Passage(through: pane, for: sample)
            let outline = Picture.Glass.Outline(inward: -sample.distance, x: sample.gradient[0], y: -sample.gradient[1])
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
                over: [read, read, read],
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
                            over: [read, read, read],
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

extension Picture.Renderer.CPU.Slab {
    /// How far from a point of a pane its glass reads, in the pane's units: the largest offset of a passage across
    /// the rim from half a pixel in, where the bend is steepest, to the level middle. Reads nearer the boundary,
    /// which bend further, find the frost's nearest edge pixel.
    static func reach(of pane: Picture.Glass.Pane, scale: Double) -> Double {
        var largest = abs(pane.glass.bend)
        let start = 0.5 / scale
        let steps = 64
        for step in 0...steps {
            let inward = start + (Swift.max(pane.rim, start) - start) * Double(step) / Double(steps)
            let passage = Picture.Glass.Pane.Passage(through: pane, for: .init(distance: -inward, gradient: Vector([1, 0])))
            let index = pane.glass.refraction?.index(at: Picture.Glass.Spectrum.range.lowerBound) ?? .vacuum
            let offset = passage.offset(for: index)
            let length = (offset[0] * offset[0] + offset[1] * offset[1]).squareRoot()
            if length.isFinite { largest = Swift.max(largest, length) }
        }
        return largest
    }

    /// A region equal to the given one that shares no storage with it, so that the threads that each sample a
    /// copy of their own do not contend for the count of one shared array.
    static func unshared(_ region: Picture.Plane.Region) -> Picture.Plane.Region {
        guard case .union(let regions, let radius) = region else { return region }
        var copies: [Picture.Plane.Region] = []
        copies.reserveCapacity(regions.count)
        for part in regions { copies.append(unshared(part)) }
        return .union(copies, radius: radius)
    }
}

extension Picture.Renderer.CPU.Slab {
    /// A region's signed distance in pixels at every eighth pixel centre of a box, from which the distance at
    /// any pixel of the box is bounded: a signed distance changes by at most the distance moved, so a pixel lies
    /// within half a cell's diagonal of the distance at the nearest point kept.
    struct Coarse {
        static let step = 8

        let box: Picture.Renderer.CPU.Box
        let columns: Int
        let distances: [Double]
    }
}

extension Picture.Renderer.CPU.Slab.Coarse {
    init(_ region: Picture.Plane.Region, over box: Picture.Renderer.CPU.Box, _ inverse: Picture.Transform, scale: Double) {
        let step = Self.step
        let columns = (box.width + step - 1) / step + 1
        let rows = (box.height + step - 1) / step + 1
        var distances = [Double](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = Double(box.left + column * step) + 0.5
                let y = Double(box.top + row * step) + 0.5
                distances[row * columns + column] = region.distance(to: Picture.Renderer.CPU.point(inverse, x, y)) * scale
            }
        }
        self.init(box: box, columns: columns, distances: distances)
    }

    /// The least and the most the distance in pixels can be at a pixel of the box.
    func bound(_ x: Int, _ y: Int) -> (lower: Double, upper: Double) {
        let step = Self.step
        let column = (x - box.left + step / 2) / step
        let row = (y - box.top + step / 2) / step
        let index = row * columns + column
        guard column >= 0, row >= 0, column < columns, index < distances.count else { return (-.infinity, .infinity) }
        let d = distances[index]
        let slack = Double(step) * 0.7072
        return (d - slack, d + slack)
    }
}
