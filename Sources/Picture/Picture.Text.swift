public import Angle
public import Byte
public import Geometry
public import ISO_14496_22
public import Matrix
import Numeric
public import Threefry
import Vector

extension Picture {
    /// A string set in a font at a size: lines of glyphs, each glyph an outline at a place.
    public struct Text: Sendable, Hashable {
        /// The lines, top to bottom.
        public let lines: [Line]

        /// The width the lines are aligned in.
        public let measure: Double

        /// The font's metrics at the text's size.
        public let metrics: Metrics

        /// The distance from one baseline to the next.
        public let leading: Double
    }
}

extension Picture.Text {
    /// Sets a string in a parsed font.
    ///
    /// `tracking` is extra advance after every glyph, as a share of the size, so that it scales with the
    /// text; `figures` sets the digits proportional or tabular.
    public init(
        _ string: String,
        font: ISO_14496_22.FontFile,
        size: Double,
        measure: Double? = nil,
        alignment: Alignment = .left,
        leading: Double? = nil,
        tracking: Double = 0,
        figures: Figures = .proportional
    ) throws(Error) {
        let metrics = try Metrics(font: font, size: size)
        if let measure {
            guard measure > 0, measure.isFinite else { throw .measure }
        }
        guard tracking.isFinite else { throw .tracking }
        let scale = size / Double(font.unitsPerEm)
        let step = leading ?? (metrics.ascent + metrics.descent + metrics.gap)
        let tracked = tracking * size
        let figure = (0x30...0x39).map { (scalar: UInt32) in font.advanceWidth(for: font.glyphIndex(for: scalar) ?? 0) }.max() ?? 0
        let upright = Picture.Transform(rows: [[scale, 0, 0], [0, -scale, 0]])
        var outlines: [UInt16: Picture.Plane.Path] = [:]
        var centred: [UInt16: Picture.Plane.Path] = [:]
        var runs: [Run] = []
        var text: [Unicode.Scalar] = []
        var bytes = string.utf8.makeIterator()
        var decoder = UTF8()
        while case .scalarValue(let scalar) = decoder.decode(&bytes) {
            text.append(scalar)
        }
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let scalars = Array(paragraph)
            let indices = scalars.map { font.glyphIndex(for: $0.value) ?? 0 }
            let tabular = scalars.map { figures == .tabular && ("0"..."9").contains($0) }
            for index in indices where outlines[index] == nil {
                do throws(ISO_14496_22.Outline.Error) {
                    outlines[index] = try font.outline(for: index).transformed(by: upright, to: Picture.Space.self)
                } catch {
                    throw .outline(error)
                }
            }
            for (index, digit) in zip(indices, tabular) where digit && centred[index] == nil {
                let shift = (Double(figure) - Double(font.advanceWidth(for: index))) / 2 * scale
                centred[index] = outlines[index]?.transformed(by: .translation(x: shift, y: 0))
            }
            let units = zip(indices, tabular).map { index, digit in digit ? figure : font.advanceWidth(for: index) }
            var starts: [Double] = [0]
            for position in indices.indices {
                var advance = Double(units[position])
                if position + 1 < indices.count, !tabular[position], !tabular[position + 1] {
                    do throws(ISO_14496_22.FontFile.ParsingError) {
                        advance += try font.kerning(left: indices[position], right: indices[position + 1]).underlying
                    } catch {
                        throw .font(error)
                    }
                }
                starts.append(starts[position] + advance * scale + tracked)
            }
            let widths = units.map { Double($0) * scale }
            let blank = scalars.map { $0 == " " }
            var start = 0
            var opportunity: Int?
            if let measure {
                for position in indices.indices where !blank[position] {
                    if position > start, blank[position - 1] { opportunity = position }
                    if let cut = opportunity, starts[position] - starts[start] + widths[position] > measure {
                        runs.append(Run(scalars: scalars, indices: indices, tabular: tabular, starts: starts, widths: widths, blank: blank, range: start..<cut))
                        start = cut
                        opportunity = nil
                    }
                }
            }
            runs.append(Run(scalars: scalars, indices: indices, tabular: tabular, starts: starts, widths: widths, blank: blank, range: start..<indices.count))
        }
        let widest = runs.reduce(0) { Swift.max($0, $1.width) }
        let within = measure ?? widest
        self.lines = runs.enumerated().map { number, run in
            let baseline = Double(number) * step
            let indent = alignment.indent(of: run.width, in: within)
            let glyphs = run.range.map { position in
                let index = run.indices[position]
                return Glyph(
                    scalar: run.scalars[position],
                    index: index,
                    origin: Picture.Plane.Point<2>([indent + run.starts[position] - run.starts[run.range.lowerBound], baseline]),
                    advance: run.widths[position],
                    outline: (run.tabular[position] ? centred[index] : outlines[index]) ?? Picture.Plane.Path(subpaths: [])
                )
            }
            return Line(glyphs: glyphs, baseline: baseline, width: run.width)
        }
        self.measure = within
        self.metrics = metrics
        self.leading = step
    }

    /// Sets a string in the font a font file's bytes hold.
    public init(
        _ string: String,
        bytes: [Byte],
        size: Double,
        measure: Double? = nil,
        alignment: Alignment = .left,
        leading: Double? = nil,
        tracking: Double = 0,
        figures: Figures = .proportional
    ) throws(Error) {
        let font: ISO_14496_22.FontFile
        do throws(ISO_14496_22.FontFile.ParsingError) {
            font = try ISO_14496_22.FontFile(data: bytes)
        } catch {
            throw .font(error)
        }
        try self.init(string, font: font, size: size, measure: measure, alignment: alignment, leading: leading, tracking: tracking, figures: figures)
    }
}

extension Picture.Text {
    /// Every glyph, line after line, in the order of the string.
    public var glyphs: [Glyph] {
        lines.flatMap(\.glyphs)
    }

    /// Every glyph's outline at its place, as one path.
    public var path: Picture.Plane.Path {
        Picture.Plane.Path(subpaths: glyphs.flatMap(\.path.subpaths))
    }

    /// The text sampled to points: every glyph's `points(spacing:seed:)`, glyph after glyph, all on one lattice.
    public func points(spacing: Double, seed: Threefry.Key? = nil) -> [Picture.Plane.Point<2>] {
        glyphs.flatMap { $0.points(spacing: spacing, seed: seed) }
    }

    /// The whole text as one shape with a fill.
    public func shape(_ fill: Picture.Shape.Fill) -> Picture.Shape {
        Picture.Shape(path, fill: fill)
    }
}

extension Picture.Text {
    /// How far the font rises above a baseline at this size: the metrics' ascent.
    public var ascent: Double { metrics.ascent }

    /// How far the font falls below a baseline at this size: the metrics' descent.
    public var descent: Double { metrics.descent }

    /// The width of the widest line.
    public var width: Double {
        lines.reduce(0) { Swift.max($0, $1.width) }
    }

    /// The size at which the widest line is as wide as a measure, and at most `maximum`.
    ///
    /// Every advance, kerning and tracking scales with the size, so the width does too, and the size is the
    /// text's size times the measure over its width; set again at that size, the text's widest line is the
    /// measure up to rounding. The lines are taken as they are set, so a text that breaks into lines at a
    /// measure may break otherwise at the new size. A text with no width gives `maximum`.
    public func size(fitting measure: Double, maximum: Double = .infinity) -> Double {
        let width = width
        guard width > 0 else { return maximum }
        return Swift.min(metrics.size * measure / width, maximum)
    }
}

extension Picture.Text {
    /// The whole text filled and put at a point: the first line's `level` passes through the point, its
    /// baseline by default, and the point is the left end, the middle or the right end of the measure as
    /// `anchor` says. It is the shape of `shape(_:)` in a group moved by `anchor.indent(of: 0, in: measure)`
    /// to the left of the point and by the level's height below it.
    public func placed(
        _ fill: Picture.Shape.Fill,
        at point: Picture.Plane.Point<2>,
        anchor: Alignment = .left,
        level: Level = .baseline
    ) -> Picture.Element {
        .group(Picture.Group([.shape(shape(fill))], transform: move(to: point, anchor: anchor, level: level)))
    }

    /// The box of the ink the text puts down where `placed(_:at:anchor:level:)` puts it: the bounding box of
    /// every glyph's path, moved as that moves the text, so it holds every point a fill of the text covers and
    /// none of the empty advance around it. Nil for a text that draws nothing, as one of spaces.
    public func bounds(
        at point: Picture.Plane.Point<2>,
        anchor: Alignment = .left,
        level: Level = .baseline
    ) -> Picture.Plane.Rectangle? {
        path.transformed(by: move(to: point, anchor: anchor, level: level)).boundingBox
    }

    /// The move `placed(_:at:anchor:level:)` makes.
    func move(to point: Picture.Plane.Point<2>, anchor: Alignment, level: Level) -> Picture.Transform {
        .translation(x: point[0] - anchor.indent(of: 0, in: measure), y: point[1] + level.height(in: metrics))
    }

    /// The whole text filled and centred on a point as a block: the point lies midway between the first
    /// line's `top`, the top of its capitals by default, and the last line's baseline, and is the left end,
    /// the middle or the right end of the measure as `anchor` says. For one line and the default top it is
    /// `placed(_:at:anchor:level:)` at `.cap(0.5)`.
    public func centered(
        _ fill: Picture.Shape.Fill,
        at point: Picture.Plane.Point<2>,
        anchor: Alignment = .left,
        top: Level = .cap(1)
    ) -> Picture.Element {
        let middle = ((lines.last?.baseline ?? 0) - top.height(in: metrics)) / 2
        let move = Picture.Transform.translation(x: point[0] - anchor.indent(of: 0, in: measure), y: point[1] - middle)
        return .group(Picture.Group([.shape(shape(fill))], transform: move))
    }
}

extension Picture.Text {
    /// Glyphs as one path: every glyph's path in order.
    public static func path(of glyphs: some Swift.Sequence<Glyph>) -> Picture.Plane.Path {
        Picture.Plane.Path(subpaths: glyphs.flatMap(\.path.subpaths))
    }

    /// The glyphs set along a circle, each turned to the circle's tangent and none bent.
    ///
    /// A glyph's place along the circle is the middle of its advance on its baseline, its distance along the
    /// line from the left end, the middle or the right end of the measure as `anchor` says, taken as arc
    /// length on the circle from the angle `start`; the angle is picture space's own, from x toward y,
    /// clockwise on a screen. The circle passes through the first line's `level`, so a later line runs on a
    /// circle that much nearer the centre, or farther for `inside`, at the same angles. Each glyph is
    /// `transformed(by:)` the map that takes that point to its place, x to the way the text runs there and y
    /// to the way the glyph's down points. A radius that is not positive and finite gives no glyphs.
    public func circled(
        center: Picture.Plane.Point<2>,
        radius: Double,
        start: Radian<Double>,
        side: Side = .outside,
        anchor: Alignment = .left,
        level: Level = .baseline
    ) -> [Glyph] {
        guard radius > 0, radius.isFinite else { return [] }
        let lift = level.height(in: metrics)
        let indent = anchor.indent(of: 0, in: measure)
        let turn: Double = side == .outside ? 1 : -1
        return glyphs.map { glyph in
            let along = glyph.origin[0] + glyph.advance / 2 - indent
            let depth = glyph.origin[1] + lift
            let angle = start.underlying + turn * along / radius
            let (cosine, sine) = (Double.cos(angle), Double.sin(angle))
            let reach = radius - turn * depth
            let place = Picture.Plane.Point<2>([center[0] + reach * cosine, center[1] + reach * sine])
            return Self.turned(glyph, to: place, along: (x: -turn * sine, y: turn * cosine))
        }
    }

    /// The glyphs set along a path by arc length, each turned to the path's direction and none bent.
    ///
    /// The path is flattened to within `tolerance`, its subpaths taken in order as one track and a closed
    /// subpath with its closing line. A glyph's place is the middle of its advance on its baseline, its
    /// distance along the line from the left end, the middle or the right end of the measure as `anchor`
    /// says, taken as length along the track from its start; before the start and past the end the track goes
    /// straight on. The track passes through the first line's `level`, and the glyphs' tops face the left of
    /// the way the path runs, which on a screen, y down, is the side a viewer sees as above for a path running
    /// to the right. A path with no length gives no glyphs.
    public func along(
        _ path: Picture.Plane.Path,
        tolerance: Picture.Plane.Length,
        anchor: Alignment = .left,
        level: Level = .baseline
    ) throws(Picture.Plane.Path.Error) -> [Glyph] {
        let flat = try path.flattened(tolerance: tolerance)
        var pieces: [(from: Picture.Plane.Point<2>, way: (x: Double, y: Double), start: Double)] = []
        var travelled = 0.0
        for subpath in flat.subpaths {
            var points = [subpath.startPoint]
            for segment in subpath.segments {
                guard case .line(let line) = segment else { continue }
                points.append(line.end)
            }
            if subpath.isClosed { points.append(subpath.startPoint) }
            for (from, to) in zip(points, points.dropFirst()) {
                let (x, y) = (to[0] - from[0], to[1] - from[1])
                let length = (x * x + y * y).squareRoot()
                guard length > 0, length.isFinite else { continue }
                pieces.append((from, (x / length, y / length), travelled))
                travelled += length
            }
        }
        guard let first = pieces.first else { return [] }
        let lift = level.height(in: metrics)
        let indent = anchor.indent(of: 0, in: measure)
        return glyphs.map { glyph in
            let along = glyph.origin[0] + glyph.advance / 2 - indent
            let depth = glyph.origin[1] + lift
            let piece = pieces.last { $0.start <= along } ?? first
            let into = along - piece.start
            let place = Picture.Plane.Point<2>([
                piece.from[0] + into * piece.way.x - depth * piece.way.y,
                piece.from[1] + into * piece.way.y + depth * piece.way.x,
            ])
            return Self.turned(glyph, to: place, along: piece.way)
        }
    }

    /// A glyph moved so that the middle of its advance on its baseline lies at a place, its x turned to a
    /// direction of unit length and its y, its down, to that direction turned a quarter from x toward y.
    static func turned(_ glyph: Glyph, to place: Picture.Plane.Point<2>, along way: (x: Double, y: Double)) -> Glyph {
        let middle = (x: glyph.origin[0] + glyph.advance / 2, y: glyph.origin[1])
        let map = Picture.Transform(rows: [
            [way.x, -way.y, place[0] - way.x * middle.x + way.y * middle.y],
            [way.y, way.x, place[1] - way.y * middle.x - way.x * middle.y],
        ])
        return glyph.transformed(by: map)
    }
}

extension Picture.Text {
    /// The glyphs wrapped round a band in space: for each glyph, in the order of `glyphs`, the model matrix
    /// that takes its `outline`, a flat path around its own origin, to its place on a circle of `radius` about
    /// the y axis, in the plane through the first line's `level`, standing upright with y up and facing out.
    ///
    /// A glyph's place along the circle is the middle of its advance, its distance along the line from the
    /// left end, the middle or the right end of the measure as `anchor` says, taken as arc length from the
    /// angle `start` about the y axis: at angle 0 the glyph stands at +z, toward an eye looking along −z,
    /// and the text reads to the right there, toward +x. A later line stands lower on the same band. An
    /// outline's point (x, y) is the model's point (x, y, 0), so `Picture.Scene.projected(_:in:tolerance:)` of
    /// the outline in a model times this matrix draws the glyph through a camera. A radius that is not
    /// positive and finite gives no matrices.
    public func wrapped(
        radius: Double,
        start: Radian<Double> = .zero,
        anchor: Alignment = .left,
        level: Level = .baseline
    ) -> [Matrix<4, 4, Double>] {
        guard radius > 0, radius.isFinite else { return [] }
        let lift = level.height(in: metrics)
        let indent = anchor.indent(of: 0, in: measure)
        return glyphs.map { glyph in
            let half = glyph.advance / 2
            let angle = start.underlying + (glyph.origin[0] + half - indent) / radius
            let (cosine, sine) = (Double.cos(angle), Double.sin(angle))
            let height = -(glyph.origin[1] + lift)
            return Matrix<4, 4, Double>(rows: [
                [cosine, 0, sine, radius * sine - half * cosine],
                [0, -1, 0, height],
                [-sine, 0, cosine, radius * cosine + half * sine],
                [0, 0, 0, 1],
            ])
        }
    }
}
