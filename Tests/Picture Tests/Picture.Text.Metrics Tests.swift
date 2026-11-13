import Picture
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    /// An `OS/2` table of a version with a cap height, an x-height and a PANOSE.
    static func os2(version: UInt16 = 4, cap: Int16? = 700, ex: Int16? = 500, panose: [UInt8] = Array(repeating: 0, count: 10)) -> ISO_14496_22.OS2 {
        ISO_14496_22.OS2(
            version: version,
            xAvgCharWidth: 500,
            usWeightClass: 400,
            usWidthClass: 5,
            fsType: ISO_14496_22.OS2.Embedding(rawValue: 0),
            ySubscriptXSize: 0,
            ySubscriptYSize: 0,
            ySubscriptXOffset: 0,
            ySubscriptYOffset: 0,
            ySuperscriptXSize: 0,
            ySuperscriptYSize: 0,
            ySuperscriptXOffset: 0,
            ySuperscriptYOffset: 0,
            yStrikeoutSize: 0,
            yStrikeoutPosition: 0,
            sFamilyClass: 0,
            panose: panose,
            ulUnicodeRange1: 0,
            ulUnicodeRange2: 0,
            ulUnicodeRange3: 0,
            ulUnicodeRange4: 0,
            achVendID: ISO_14496_22.Tag(value: 0),
            fsSelection: ISO_14496_22.OS2.Selection(rawValue: 0),
            usFirstCharIndex: 0x20,
            usLastCharIndex: 0x78,
            sTypoAscender: 800,
            sTypoDescender: -200,
            sTypoLineGap: 100,
            usWinAscent: 800,
            usWinDescent: 200,
            sxHeight: version >= 2 ? ex : nil,
            sCapHeight: version >= 2 ? cap : nil
        )
    }

    static let capital: [Corner] = [(0, 0), (600, 0), (600, 700), (0, 700)]
    static let small: [Corner] = [(0, 0), (400, 0), (400, 500), (0, 500)]
    static let one: [Corner] = [(0, 0), (200, 0), (200, 700), (0, 700)]
    static let zero: [Corner] = [(0, 0), (500, 0), (500, 700), (0, 700)]
    static let eight: [Corner] = [(0, 0), (450, 0), (450, 700), (0, 700)]

    /// Glyph 0 is a box, 1 is "A", 2 is "V", 3 the space, 4 "H" (a box 700 high), 5 "x" (a box 500 high),
    /// 6 "1" (advance 400), 7 "0" (advance 600) and 8 "8" (advance 550). The other digits are glyph 0, of
    /// advance 500. "1" and "0" kern both ways, as do "A" and "V".
    static func typeset(os2: ISO_14496_22.OS2? = nil, fixed: Bool = false) -> ISO_14496_22.FontFile {
        let glyphs = [glyph([box]), glyph([triangle]), glyph([wedge]), glyph([]), glyph([capital]), glyph([small]), glyph([one]), glyph([zero]), glyph([eight])]
        let advances: [UInt16] = [500, 600, 600, 300, 700, 500, 400, 600, 550]
        let offsets = glyphs.reduce(into: [UInt32(0)]) { $0.append(($0.last ?? 0) + UInt32($1.count)) }
        return ISO_14496_22.FontFile(
            data: [],
            head: ISO_14496_22.HeadTable(unitsPerEm: 1000),
            hhea: ISO_14496_22.HheaTable(ascender: 800, descender: -200, lineGap: 100, advanceWidthMax: 700, numberOfHMetrics: 9),
            hmtx: ISO_14496_22.HmtxTable(
                hMetrics: advances.map { ISO_14496_22.LongHorMetric(advanceWidth: $0, leftSideBearing: 0) },
                leftSideBearings: [],
                numberOfHMetrics: 9
            ),
            maxp: ISO_14496_22.MaxpTable(numGlyphs: 9),
            cmap: ISO_14496_22.CmapTable(
                version: 0,
                encodingRecords: [],
                unicodeMapping: [0x41: 1, 0x56: 2, 0x20: 3, 0x48: 4, 0x78: 5, 0x31: 6, 0x30: 7, 0x38: 8]
            ),
            name: ISO_14496_22.NameTable(format: 0, nameRecords: [], strings: [:]),
            post: ISO_14496_22.PostTable(
                version: ISO_14496_22.Fixed(integer: 3, fraction: 0),
                italicAngle: 0,
                underlinePosition: -100,
                underlineThickness: 50,
                isFixedPitch: fixed
            ),
            os2: os2,
            loca: ISO_14496_22.LocaTable(offsets: offsets),
            glyf: ISO_14496_22.GlyfTable(data: glyphs.flatMap { $0 }.map(Byte.init(_:)), tableOffset: 0),
            kern: ISO_14496_22.Kern(data: kern([(1, 2, -100), (6, 7, -50), (7, 6, -30)]).map(Byte.init(_:)))
        )
    }

    @Test
    func `Cap height and x-height come from the OS-2 table, at the size`() throws {
        let metrics = try Picture.Text.Metrics(font: Self.typeset(os2: Self.os2(cap: 650, ex: 450)), size: 100)
        #expect(metrics.size == 100)
        #expect(metrics.cap == 65)
        #expect(metrics.ex == 45)
        #expect(metrics.ascent == 80)
        #expect(metrics.descent == 20)
        #expect(metrics.gap == 10)
        let text = try Picture.Text("H", font: Self.typeset(os2: Self.os2(cap: 650, ex: 450)), size: 100)
        #expect(text.metrics == metrics)
        #expect(text.ascent == 80 && text.descent == 20)
    }

    @Test
    func `Without a height in the table, the capital H and the lowercase x are measured`() throws {
        let absent = try Picture.Text.Metrics(font: Self.typeset(), size: 10)
        #expect(absent.cap == 7)
        #expect(absent.ex == 5)
        let early = try Picture.Text.Metrics(font: Self.typeset(os2: Self.os2(version: 1)), size: 10)
        #expect(early.cap == 7 && early.ex == 5)
        let zero = try Picture.Text.Metrics(font: Self.typeset(os2: Self.os2(cap: 0, ex: 0)), size: 10)
        #expect(zero.cap == 7 && zero.ex == 5)
        let plain = try Picture.Text.Metrics(font: Self.font(), size: 10)
        #expect(plain.cap == plain.ascent)
        #expect(plain.ex == plain.cap)
    }

    @Test
    func `A font is fixed pitch by its post table or its PANOSE, and its pitch is the space's advance`() throws {
        #expect(try Picture.Text.Metrics(font: Self.typeset(), size: 100).pitch == nil)
        #expect(try Picture.Text.Metrics(font: Self.typeset(fixed: true), size: 100).pitch == 30)
        let monospaced = Self.os2(panose: [2, 0, 0, 9, 0, 0, 0, 0, 0, 0])
        #expect(try Picture.Text.Metrics(font: Self.typeset(os2: monospaced), size: 100).pitch == 30)
        let script = Self.os2(panose: [3, 0, 0, 9, 0, 0, 0, 0, 0, 0])
        #expect(try Picture.Text.Metrics(font: Self.typeset(os2: script), size: 100).pitch == nil)
    }

    @Test
    func `A level stands its share of a metric above the baseline`() throws {
        let metrics = try Picture.Text.Metrics(font: Self.typeset(), size: 100)
        #expect(Picture.Text.Level.baseline.height(in: metrics) == 0)
        #expect(Picture.Text.Level.ascent.height(in: metrics) == 80)
        #expect(Picture.Text.Level.descent.height(in: metrics) == -20)
        #expect(Picture.Text.Level.cap(0.5).height(in: metrics) == 35)
        #expect(Picture.Text.Level.ex(1).height(in: metrics) == 50)
        #expect(throws: Picture.Text.Error.size) { try Picture.Text.Metrics(font: Self.typeset(), size: 0) }
    }
}
