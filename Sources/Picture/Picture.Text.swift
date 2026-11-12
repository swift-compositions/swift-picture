public import Byte
public import ISO_14496_22
import Matrix
import Vector

extension Picture {
    /// A string set in a font at a size: lines of glyphs, each glyph an outline at a place.
    public struct Text: Sendable, Hashable {
        /// The lines, top to bottom.
        public let lines: [Line]

        /// The width the lines are aligned in.
        public let measure: Double

        /// How far the font rises above a baseline at this size.
        public let ascent: Double

        /// How far the font falls below a baseline at this size.
        public let descent: Double

        /// The distance from one baseline to the next.
        public let leading: Double
    }
}

extension Picture.Text {
    /// Sets a string in a parsed font.
    public init(
        _ string: String,
        font: ISO_14496_22.FontFile,
        size: Double,
        measure: Double? = nil,
        alignment: Alignment = .left,
        leading: Double? = nil
    ) throws(Error) {
        guard size > 0, size.isFinite else { throw .size }
        guard font.unitsPerEm > 0 else { throw .units }
        if let measure {
            guard measure > 0, measure.isFinite else { throw .measure }
        }
        let scale = size / Double(font.unitsPerEm)
        let ascent = Double(font.ascender) * scale
        let descent = -Double(font.descender) * scale
        let step = leading ?? (ascent + descent + Double(font.lineGap) * scale)
        let upright = Picture.Transform(rows: [[scale, 0, 0], [0, -scale, 0]])
        var outlines: [UInt16: Picture.Path] = [:]
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
            for index in indices where outlines[index] == nil {
                do throws(ISO_14496_22.Outline.Error) {
                    outlines[index] = try font.outline(for: index).transformed(by: upright, to: Picture.Space.self)
                } catch {
                    throw .outline(error)
                }
            }
            var starts: [Double] = [0]
            for position in indices.indices {
                var advance = Double(font.advanceWidth(for: indices[position]))
                if position + 1 < indices.count {
                    do throws(ISO_14496_22.FontFile.ParsingError) {
                        advance += try font.kerning(left: indices[position], right: indices[position + 1]).underlying
                    } catch {
                        throw .font(error)
                    }
                }
                starts.append(starts[position] + advance * scale)
            }
            let widths = indices.map { Double(font.advanceWidth(for: $0)) * scale }
            let blank = scalars.map { $0 == " " }
            var start = 0
            var opportunity: Int?
            if let measure {
                for position in indices.indices where !blank[position] {
                    if position > start, blank[position - 1] { opportunity = position }
                    if let cut = opportunity, starts[position] - starts[start] + widths[position] > measure {
                        runs.append(Run(scalars: scalars, indices: indices, starts: starts, widths: widths, blank: blank, range: start..<cut))
                        start = cut
                        opportunity = nil
                    }
                }
            }
            runs.append(Run(scalars: scalars, indices: indices, starts: starts, widths: widths, blank: blank, range: start..<indices.count))
        }
        let widest = runs.reduce(0) { Swift.max($0, $1.width) }
        let within = measure ?? widest
        self.lines = runs.enumerated().map { number, run in
            let baseline = Double(number) * step
            let indent = alignment.indent(of: run.width, in: within)
            let glyphs = run.range.map { position in
                Glyph(
                    scalar: run.scalars[position],
                    index: run.indices[position],
                    origin: Picture.Point([indent + run.starts[position] - run.starts[run.range.lowerBound], baseline]),
                    advance: run.widths[position],
                    outline: outlines[run.indices[position]] ?? Picture.Path(subpaths: [])
                )
            }
            return Line(glyphs: glyphs, baseline: baseline, width: run.width)
        }
        self.measure = within
        self.ascent = ascent
        self.descent = descent
        self.leading = step
    }

    /// Sets a string in the font a font file's bytes hold.
    public init(
        _ string: String,
        bytes: [Byte],
        size: Double,
        measure: Double? = nil,
        alignment: Alignment = .left,
        leading: Double? = nil
    ) throws(Error) {
        let font: ISO_14496_22.FontFile
        do throws(ISO_14496_22.FontFile.ParsingError) {
            font = try ISO_14496_22.FontFile(data: bytes)
        } catch {
            throw .font(error)
        }
        try self.init(string, font: font, size: size, measure: measure, alignment: alignment, leading: leading)
    }
}

extension Picture.Text {
    /// Every glyph, line after line, in the order of the string.
    public var glyphs: [Glyph] {
        lines.flatMap(\.glyphs)
    }

    /// Every glyph's outline at its place, as one path.
    public var path: Picture.Path {
        Picture.Path(subpaths: glyphs.flatMap(\.path.subpaths))
    }

    /// The whole text as one shape with a fill.
    public func shape(_ fill: Picture.Shape.Fill) -> Picture.Shape {
        Picture.Shape(path, fill: fill)
    }
}
