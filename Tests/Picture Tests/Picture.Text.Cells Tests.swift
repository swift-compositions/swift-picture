import Picture
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    @Test
    func `Figures in cells keep every digit still as a number changes, its point in half a cell`() throws {
        let font = Self.typeset()
        let cells = Picture.Text.Figures.cells(.init(punctuation: 0.5))
        let numbers = ["10.8", "88.0", "01.1", "80.8"]
        let set = try numbers.map { number throws(Picture.Text.Error) in try Picture.Text(number, font: font, size: 100, figures: cells) }
        for text in set {
            #expect(Self.origins(text) == [[0, 0], [60, 0], [120, 0], [150, 0]])
            #expect(text.glyphs.map(\.advance) == [60, 60, 30, 60])
        }
        let natural = try numbers.map { number throws(Picture.Text.Error) in try Picture.Text(number, font: font, size: 100, figures: .tabular) }
        #expect(natural.allSatisfy { Self.origins($0) == [[0, 0], [60, 0], [120, 0], [170, 0]] })
        let point = set[0].glyphs[2]
        let alone = try Picture.Text(".", font: font, size: 100).glyphs[0].outline
        #expect(point.outline == alone.transformed(by: .translation(x: -10, y: 0)))
    }

    @Test
    func `Cells with no share for a class leave the tabular setting as it was`() throws {
        let font = Self.typeset()
        for string in ["1028", "10 8", "AV 10", "8.1"] {
            let tabular = try Picture.Text(string, font: font, size: 37, tracking: 0.02, figures: .tabular)
            let cells = try Picture.Text(string, font: font, size: 37, tracking: 0.02, figures: .cells(.init()))
            #expect(tabular == cells)
        }
        #expect(Picture.Text.Figures.proportional.share(of: "1") == nil)
        #expect(Picture.Text.Figures.tabular.share(of: "1") == 1)
        #expect(Picture.Text.Figures.tabular.share(of: ".") == nil)
        let all = Picture.Text.Figures.Cells(punctuation: 0.5, symbols: 0.75, spaces: 0.25)
        #expect(all.share(of: ",") == 0.5 && all.share(of: "%") == 0.5 && all.share(of: "+") == 0.75 && all.share(of: " ") == 0.25)
        #expect(all.share(of: "A") == nil)
    }
}
