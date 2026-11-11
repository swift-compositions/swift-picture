import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A text is glyph outlines at places` {}
}

extension `Picture Tests`.`A text is glyph outlines at places` {
    typealias Tests = `Picture Tests`
    typealias Corner = (x: Int, y: Int)

    static func be16(_ value: Int) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    /// One TrueType glyph of straight contours.
    static func glyph(_ contours: [[Corner]]) -> [UInt8] {
        guard !contours.isEmpty else { return [] }
        let points = contours.flatMap { $0 }
        var ends: [UInt8] = []
        var last = -1
        contours.forEach { contour in
            last += contour.count
            ends += be16(last)
        }
        var xs: [UInt8] = []
        var ys: [UInt8] = []
        var previous: Corner = (0, 0)
        points.forEach { point in
            xs += be16(point.x - previous.x)
            ys += be16(point.y - previous.y)
            previous = point
        }
        let header = be16(contours.count) + be16(0) + be16(0) + be16(0) + be16(0)
        return header + ends + be16(0) + points.map { _ in 1 } + xs + ys
    }

    /// A `kern` table of version 0 with one format 0 subtable.
    static func kern(_ pairs: [(left: Int, right: Int, value: Int)]) -> [UInt8] {
        let sorted = pairs.sorted { ($0.left, $0.right) < ($1.left, $1.right) }
        let body = be16(pairs.count) + be16(0) + be16(0) + be16(0) + sorted.flatMap { be16($0.left) + be16($0.right) + be16($0.value) }
        return be16(0) + be16(1) + be16(0) + be16(6 + body.count) + be16(0x0001) + body
    }

    static let box: [Corner] = [(0, 0), (400, 0), (400, 700), (0, 700)]
    static let triangle: [Corner] = [(0, 0), (500, 0), (250, 700)]
    static let wedge: [Corner] = [(0, 700), (250, 0), (500, 700)]

    /// Glyph 0 is a box, 1 is "A", 2 is "V", 3 is the space, 4 is "B" and 5 is U+0301.
    static func font(unitsPerEm: UInt16 = 1000, outlines: Bool = true) -> ISO_14496_22.FontFile {
        let glyphs = [glyph([box]), glyph([triangle]), glyph([wedge]), glyph([]), glyph([box, triangle]), glyph([triangle])]
        let advances: [UInt16] = [500, 600, 600, 300, 700, 0]
        let offsets = glyphs.reduce(into: [UInt32(0)]) { $0.append(($0.last ?? 0) + UInt32($1.count)) }
        return ISO_14496_22.FontFile(
            data: [],
            head: ISO_14496_22.HeadTable(unitsPerEm: unitsPerEm),
            hhea: ISO_14496_22.HheaTable(ascender: 800, descender: -200, lineGap: 100, advanceWidthMax: 700, numberOfHMetrics: 6),
            hmtx: ISO_14496_22.HmtxTable(
                hMetrics: advances.map { ISO_14496_22.LongHorMetric(advanceWidth: $0, leftSideBearing: 0) },
                leftSideBearings: [],
                numberOfHMetrics: 6
            ),
            maxp: ISO_14496_22.MaxpTable(numGlyphs: 6),
            cmap: ISO_14496_22.CmapTable(version: 0, encodingRecords: [], unicodeMapping: [0x41: 1, 0x56: 2, 0x20: 3, 0x42: 4, 0x301: 5]),
            name: ISO_14496_22.NameTable(format: 0, nameRecords: [], strings: [:]),
            post: ISO_14496_22.PostTable(
                version: ISO_14496_22.Fixed(integer: 3, fraction: 0),
                italicAngle: 0,
                underlinePosition: -100,
                underlineThickness: 50,
                isFixedPitch: false
            ),
            loca: outlines ? ISO_14496_22.LocaTable(offsets: offsets) : nil,
            glyf: outlines ? ISO_14496_22.GlyfTable(data: glyphs.flatMap { $0 }.map(Byte.init(_:)), tableOffset: 0) : nil,
            kern: ISO_14496_22.Kern(data: kern([(1, 2, -100), (2, 1, -50), (1, 3, 20)]).map(Byte.init(_:)))
        )
    }

    static func corners(_ path: Picture.Path) -> [[[Double]]] {
        path.subpaths.map { subpath in
            [[subpath.startPoint[0], subpath.startPoint[1]]]
                + subpath.segments.compactMap { segment in
                    guard case .line(let line) = segment else { return nil }
                    return [line.end[0], line.end[1]]
                }
        }
    }

    static func origins(_ text: Picture.Text) -> [[Double]] {
        text.glyphs.map { [$0.origin[0], $0.origin[1]] }
    }

    @Test
    func `Every code point but the line feed becomes one glyph, in order, through the font's character map`() throws {
        let text = try Picture.Text("AVB A", font: Self.font(), size: 100)
        #expect(text.glyphs.map(\.index) == [1, 2, 4, 3, 1])
        #expect(text.glyphs.map(\.scalar) == ["A", "V", "B", " ", "A"])
        #expect(text.lines.count == 1)
        #expect(text.lines[0].glyphs == text.glyphs)
        let marked = try Picture.Text("A\u{301}", font: Self.font(), size: 100)
        #expect(marked.glyphs.map(\.index) == [1, 5])
        #expect(marked.glyphs.map(\.scalar) == ["A", "\u{301}"])
    }

    @Test
    func `A code point the font does not map becomes glyph 0`() throws {
        let text = try Picture.Text("AxV", font: Self.font(), size: 100)
        #expect(text.glyphs.map(\.index) == [1, 0, 2])
        #expect(text.glyphs[1].scalar == "x")
        #expect(text.glyphs[1].advance == 50)
        #expect(Self.corners(text.glyphs[1].outline) == [[[0, 0], [40, 0], [40, -70], [0, -70], [0, 0]]])
        #expect(Self.origins(text) == [[0, 0], [60, 0], [110, 0]])
    }

    @Test
    func `The pen moves by each glyph's advance plus the pair's kerning, scaled by size over units per em`() throws {
        let text = try Picture.Text("AVA B", font: Self.font(), size: 100)
        #expect(Self.origins(text) == [[0, 0], [50, 0], [105, 0], [167, 0], [197, 0]])
        #expect(text.glyphs.map(\.advance) == [60, 60, 60, 30, 70])
        #expect(text.lines[0].width == 267)
        let half = try Picture.Text("AVA B", font: Self.font(), size: 50)
        #expect(Self.origins(half) == [[0, 0], [25, 0], [52.5, 0], [83.5, 0], [98.5, 0]])
        let coarse = try Picture.Text("AV", font: Self.font(unitsPerEm: 2000), size: 100)
        #expect(Self.origins(coarse) == [[0, 0], [25, 0]])
    }

    @Test
    func `An outline is the font's, scaled, with the font's up turned toward smaller y`() throws {
        let text = try Picture.Text("AV B", font: Self.font(), size: 100)
        #expect(Self.corners(text.glyphs[0].outline) == [[[0, 0], [50, 0], [25, -70], [0, 0]]])
        #expect(Self.corners(text.glyphs[1].outline) == [[[0, -70], [25, 0], [50, -70], [0, -70]]])
        #expect(text.glyphs[2].outline.isEmpty)
        #expect(Self.corners(text.glyphs[3].outline).count == 2)
        #expect(text.glyphs[0].outline.subpaths.map(\.isClosed) == [true])
        let small = try Picture.Text("A", font: Self.font(), size: 10)
        #expect(Self.corners(small.glyphs[0].outline) == [[[0, 0], [5, 0], [2.5, -7], [0, 0]]])
    }

    @Test
    func `A glyph's path is its outline moved to its origin, and the text's path is every glyph's path in order`() throws {
        let text = try Picture.Text("AV\nA", font: Self.font(), size: 100)
        #expect(Self.corners(text.glyphs[1].path) == [[[50, -70], [75, 0], [100, -70], [50, -70]]])
        #expect(Self.corners(text.glyphs[2].path) == [[[0, 110], [50, 110], [25, 40], [0, 110]]])
        #expect(text.path.subpaths == text.glyphs.flatMap(\.path.subpaths))
        #expect(text.path.subpaths.count == 3)
        let fill = Picture.Shape.Fill(.solid(.white), rule: .evenodd)
        #expect(text.shape(fill) == Picture.Shape(text.path, fill: fill))
    }

    @Test
    func `A line feed starts a new line one leading further down, and kerning does not reach across it`() throws {
        let text = try Picture.Text("AV\n\nVA", font: Self.font(), size: 100)
        #expect(text.lines.count == 3)
        #expect(text.lines.map(\.baseline) == [0, 110, 220])
        #expect(text.lines.map(\.glyphs.count) == [2, 0, 2])
        #expect(text.lines[1].width == 0)
        #expect(Self.origins(text) == [[0, 0], [50, 0], [0, 220], [55, 220]])
        #expect(text.glyphs.count == 4)
        let apart = try Picture.Text("A\nV", font: Self.font(), size: 100)
        #expect(Self.origins(apart) == [[0, 0], [0, 110]])
        #expect(try Picture.Text("", font: Self.font(), size: 100).lines.map(\.glyphs.count) == [0])
        #expect(try Picture.Text("A\n", font: Self.font(), size: 100).lines.map(\.glyphs.count) == [1, 0])
    }

    @Test
    func `The font's ascender, descender and line gap give ascent, descent and leading, and a leading given wins`() throws {
        let text = try Picture.Text("A", font: Self.font(), size: 100)
        #expect(text.ascent == 80)
        #expect(text.descent == 20)
        #expect(text.leading == 110)
        let tight = try Picture.Text("A\nA", font: Self.font(), size: 100, leading: 64)
        #expect(tight.leading == 64)
        #expect(tight.lines.map(\.baseline) == [0, 64])
        #expect(tight.ascent == 80)
    }

    @Test
    func `A line takes as many words as fit the measure, and the spaces at the break stay at its end`() throws {
        let text = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320)
        #expect(text.lines.map(\.glyphs.count) == [6, 2])
        #expect(text.lines.map(\.width) == [310, 140])
        #expect(text.lines[0].glyphs.map(\.scalar) == ["B", "B", " ", "B", "B", " "])
        #expect(text.lines[0].glyphs.last?.origin == Tests.at(310, 0))
        #expect(text.lines[1].glyphs.map(\.origin) == [Tests.at(0, 110), Tests.at(70, 110)])
        #expect(text.glyphs.count == 8)
        let exact = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 310)
        #expect(exact.lines.map(\.glyphs.count) == [6, 2])
        let narrow = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 309)
        #expect(narrow.lines.map(\.glyphs.count) == [3, 3, 2])
        let wide = try Picture.Text("BB  BB", font: Self.font(), size: 100, measure: 150)
        #expect(wide.lines.map(\.glyphs.count) == [4, 2])
        #expect(wide.lines[0].width == 140)
    }

    @Test
    func `A word wider than the measure stands alone on its line and is not broken`() throws {
        let text = try Picture.Text("B BBBB B", font: Self.font(), size: 100, measure: 150)
        #expect(text.lines.map(\.glyphs.count) == [2, 5, 1])
        #expect(text.lines.map(\.width) == [70, 280, 70])
        let first = try Picture.Text("BBBB B", font: Self.font(), size: 100, measure: 150)
        #expect(first.lines.map(\.glyphs.count) == [5, 1])
        let unwrapped = try Picture.Text("B BBBB B", font: Self.font(), size: 100)
        #expect(unwrapped.lines.count == 1)
        let breaks = try Picture.Text("B B\nB B", font: Self.font(), size: 100, measure: 150)
        #expect(breaks.lines.map(\.glyphs.count) == [2, 1, 2, 1])
        #expect(breaks.lines.map(\.baseline) == [0, 110, 220, 330])
    }

    @Test
    func `Lines are aligned in the measure by their width without trailing spaces`() throws {
        let left = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320)
        #expect(left.measure == 320)
        #expect(left.lines.map { $0.glyphs.first?.origin[0] } == [0, 0])
        let center = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320, alignment: .center)
        #expect(center.lines.map { $0.glyphs.first?.origin[0] } == [5, 90])
        let right = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320, alignment: .right)
        #expect(right.lines.map { $0.glyphs.first?.origin[0] } == [10, 180])
        #expect(right.lines[1].glyphs.map(\.origin) == [Tests.at(180, 110), Tests.at(250, 110)])
    }

    @Test
    func `Without a measure, lines are aligned in the width of the widest`() throws {
        let text = try Picture.Text("BBB\nB\nBB ", font: Self.font(), size: 100, alignment: .right)
        #expect(text.measure == 210)
        #expect(text.lines.map { $0.glyphs.first?.origin[0] } == [0, 140, 70])
        let center = try Picture.Text("BBB\nB", font: Self.font(), size: 100, alignment: .center)
        #expect(center.lines.map { $0.glyphs.first?.origin[0] } == [0, 70])
        #expect(Picture.Text.Alignment.allCases == [.left, .center, .right])
        #expect(Picture.Text.Alignment.center.indent(of: 30, in: 100) == 35)
        #expect(Picture.Text.Alignment.right.indent(of: 30, in: 100) == 70)
        #expect(Picture.Text.Alignment.left.indent(of: 30, in: 100) == 0)
    }

    @Test
    func `A size, a measure or an em that is not positive and finite is refused`() {
        #expect(throws: Picture.Text.Error.size) { try Picture.Text("A", font: Self.font(), size: 0) }
        #expect(throws: Picture.Text.Error.size) { try Picture.Text("A", font: Self.font(), size: -12) }
        #expect(throws: Picture.Text.Error.size) { try Picture.Text("A", font: Self.font(), size: .nan) }
        #expect(throws: Picture.Text.Error.size) { try Picture.Text("A", font: Self.font(), size: .infinity) }
        #expect(throws: Picture.Text.Error.measure) { try Picture.Text("A", font: Self.font(), size: 10, measure: 0) }
        #expect(throws: Picture.Text.Error.measure) { try Picture.Text("A", font: Self.font(), size: 10, measure: .nan) }
        #expect(throws: Picture.Text.Error.measure) { try Picture.Text("A", font: Self.font(), size: 10, measure: .infinity) }
        #expect(throws: Picture.Text.Error.units) { try Picture.Text("A", font: Self.font(unitsPerEm: 0), size: 10) }
    }

    @Test
    func `Bytes that are not a font, and a font without outlines, fail with the font package's errors`() {
        #expect(throws: Picture.Text.Error.outline(.absent)) { try Picture.Text("A", font: Self.font(outlines: false), size: 10) }
        let junk = [0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0].map(Byte.init(_:))
        var failure: Picture.Text.Error?
        do {
            _ = try Picture.Text("A", bytes: junk, size: 10)
        } catch {
            failure = error
        }
        guard case .font = failure else {
            Issue.record("Bytes that are not a font fail with .font, not \(String(describing: failure))")
            return
        }
    }
}
