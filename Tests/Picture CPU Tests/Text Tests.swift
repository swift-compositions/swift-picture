import ISO_14496_22_Test_Support
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

    static let box: [Corner] = [(0, 0), (400, 0), (400, 700), (0, 700)]
    static let triangle: [Corner] = [(0, 0), (500, 0), (250, 700)]
    static let wedge: [Corner] = [(0, 700), (250, 0), (500, 700)]

    /// Glyph 0 is a box, 1 is "A", 2 is "V", 3 is the space, 4 is "B" and 5 is U+0301.
    static func font() -> ISO_14496_22.FontFile {
        ISO_14496_22.FontFile(
            sketches: [
                .init(advance: 500, contours: [box]), .init(advance: 600, contours: [triangle]),
                .init(advance: 600, contours: [wedge]), .init(advance: 300), .init(advance: 700, contours: [box, triangle]),
                .init(advance: 0, contours: [triangle]),
            ],
            mapping: [0x41: 1, 0x56: 2, 0x20: 3, 0x42: 4, 0x301: 5],
            kerning: [(1, 2, -100), (2, 1, -50), (1, 3, 20)]
        )
    }

    @Test
    func `A text's shape draws as the fill of its path, and glyph by glyph as one`() throws {
        let text = try Typesetting.Text("AV B", font: Self.font(), size: 20)
        let fill = Picture.Shape.Fill(.solid(Tests.translucent))
        let placed = Picture.Group([.shape(text.shape(fill))], transform: .translation(Vector([2, 22])))
        let backdrop = Tests.canvas(60, 30, Tests.blue.pixel)
        let whole = try Tests.drawn([.group(placed)], on: backdrop)
        let path = try Tests.drawn([.group(.init([.shape(.init(Picture.Plane.Path(text.path), fill: fill))], transform: .translation(Vector([2, 22]))))], on: backdrop)
        #expect(whole == path)
        let glyphs = Picture(text.glyphs.map { .shape(.init(Picture.Plane.Path($0.path), fill: fill)) })
        let apart = try Tests.drawn([.group(.init(glyphs, transform: .translation(Vector([2, 22]))))], on: backdrop)
        #expect(Tests.close(whole, apart))
        #expect(whole != backdrop)
        let inside = Tests.at(whole, 7, 18)
        #expect(inside == Tests.translucent.pixel.composited(over: Tests.blue.pixel))
    }
}
