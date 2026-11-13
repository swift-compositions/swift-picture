import Picture
import Picture_Test_Support
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    static func reading() -> Picture.Reading {
        Picture.Reading(fonts: [font()])
    }

    @Test
    func `A reading reads back the words a placed text shows, at any size, place and turn`() throws {
        let reading = Self.reading()
        let fill = Picture.Shape.Fill(.solid(.white))
        let text = try Picture.Text("AV BA", font: Self.font(), size: 24)
        #expect(reading.lines(in: [text.placed(fill, at: Tests.at(100, 50))]) == ["AV BA"])
        let turned = Picture.Transform.rotation(Radian(0.7), about: Tests.at(10, 10)).multiplied(by: .scale(3, about: Tests.at(0, 0)))
        #expect(reading.lines(in: [.group(Picture.Group([text.placed(fill, at: Tests.at(100, 50))], transform: turned))]) == ["AV BA"])
        let below = try Picture.Text("BAV", font: Self.font(), size: 12)
        let both: Picture = [text.placed(fill, at: Tests.at(0, 0)), below.placed(fill, at: Tests.at(40, 80))]
        #expect(Set(reading.lines(in: both)) == ["AV BA", "BAV"])
        #expect(reading.reads("BA", in: both) && reading.reads("BAV", in: both) && !reading.reads("VB", in: both))
    }

    @Test
    func `A reading sees through layers and kept images, and not through what is invisible`() throws {
        let reading = Self.reading()
        let text = try Picture.Text("AB", font: Self.font(), size: 20)
        let shown: Picture = [text.placed(.init(.solid(.white)), at: Tests.at(10, 40))]
        #expect(reading.lines(in: [.layer(Picture.Layer(shown, opacity: 0.5))]) == ["AB"])
        #expect(reading.lines(in: [.layer(Picture.Layer(shown, opacity: 0))]).isEmpty)
        #expect(reading.lines(in: [text.placed(.init(.solid(.clear)), at: Tests.at(10, 40))]).isEmpty)
        let kept = Picture.Element.image(shown, in: .init(llx: 0, lly: 0, urx: 100, ury: 100), scale: 1)
        #expect(reading.lines(in: [kept]) == ["AB"])
        #expect(reading.lines(in: [Tests.shape(4, .white)]).isEmpty)
    }

    @Test
    func `A line holds a phrase only as whole words`() {
        #expect(Picture.Reading.line("ship it now", holds: "it"))
        #expect(!Picture.Reading.line("ship it now", holds: "hi"))
        #expect(Picture.Reading.line("ship it now", holds: "ship it now"))
        #expect(Picture.Reading.line("v 6.2!", holds: "6.2") && Picture.Reading.line("v 6.2!", holds: "6."))
        #expect(!Picture.Reading.line("v6.2!", holds: "6.2"))
        #expect(!Picture.Reading.line("short", holds: "longer phrase"))
        #expect(!Picture.Reading.line("anything", holds: ""))
    }
}
