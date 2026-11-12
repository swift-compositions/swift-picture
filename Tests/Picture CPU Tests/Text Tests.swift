import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer never sees a font: text is drawn as its glyphs' paths` {}
}

extension `Picture CPU Tests`.`A renderer never sees a font: text is drawn as its glyphs' paths` {
    typealias Tests = `Picture CPU Tests`
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

    @Test
    func `A text's shape draws as the fill of its path, and glyph by glyph as one`() throws {
        let text = try Picture.Text("AV B", font: Self.font(), size: 20)
        let fill = Picture.Shape.Fill(.solid(Tests.translucent))
        let placed = Picture.Group([.shape(text.shape(fill))], transform: .translation(Vector([2, 22])))
        let backdrop = Tests.canvas(60, 30, Tests.blue.pixel)
        let whole = try Tests.drawn([.group(placed)], on: backdrop)
        let path = try Tests.drawn([.group(.init([.shape(.init(text.path, fill: fill))], transform: .translation(Vector([2, 22]))))], on: backdrop)
        #expect(whole == path)
        let glyphs = Picture(text.glyphs.map { .shape(.init($0.path, fill: fill)) })
        let apart = try Tests.drawn([.group(.init(glyphs, transform: .translation(Vector([2, 22]))))], on: backdrop)
        #expect(Tests.close(whole, apart))
        #expect(whole != backdrop)
        let inside = Tests.at(whole, 7, 18)
        #expect(inside == Tests.translucent.pixel.composited(over: Tests.blue.pixel))
    }
}
