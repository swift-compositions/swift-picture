import Picture
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    @Test
    func `A placed text's bounds hold its ink and move with it`() throws {
        let text = try Picture.Text("AV B\nVA", font: Self.font(), size: 10)
        let point = Picture.Plane.Point<2>([100, 50])
        for anchor: Picture.Text.Alignment in [.left, .center, .right] {
            for level: Picture.Text.Level in [.baseline, .cap(0.5), .ascent] {
                let bounds = try #require(text.bounds(at: point, anchor: anchor, level: level))
                guard case .group(let group) = text.placed(.init(.solid(.white)), at: point, anchor: anchor, level: level) else {
                    Issue.record("a placed text is a group")
                    continue
                }
                let ink = try #require(text.path.transformed(by: group.transform).boundingBox)
                #expect(bounds == ink)
                for glyph in text.glyphs {
                    guard let box = glyph.path.transformed(by: group.transform).boundingBox else { continue }
                    #expect(box.llx >= bounds.llx && box.lly >= bounds.lly && box.urx <= bounds.urx && box.ury <= bounds.ury)
                }
            }
        }
        let plain = try #require(text.bounds(at: Picture.Plane.Point<2>([0, 0])))
        #expect(plain.llx.underlying == 0 && abs(plain.ury.underlying - 11) < 1e-9)
        #expect(try Picture.Text("  ", font: Self.font(), size: 10).bounds(at: point) == nil)
    }
}
