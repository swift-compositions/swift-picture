import Picture
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    @Test
    func `A placed text stands with its first baseline through the point, from either end or the middle`() throws {
        let text = try Picture.Text("AV", font: Self.font(), size: 10)
        let fill = Picture.Shape.Fill(.solid(.white))
        let point = Picture.Plane.Point<2>([100, 50])
        #expect(text.placed(fill, at: point) == .group(Picture.Group([.shape(text.shape(fill))], transform: .translation(x: 100, y: 50))))
        let width = text.measure
        #expect(text.placed(fill, at: point, anchor: .center) == .group(Picture.Group([.shape(text.shape(fill))], transform: .translation(x: 100 - width / 2, y: 50))))
        #expect(text.placed(fill, at: point, anchor: .right) == .group(Picture.Group([.shape(text.shape(fill))], transform: .translation(x: 100 - width, y: 50))))
    }
}
