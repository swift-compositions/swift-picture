import Picture
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    @Test
    func `Tracking adds its share of the size after every glyph, so a line of n glyphs widens by n − 1 times it`() throws {
        let plain = try Picture.Text("AVA B\nAV", font: Self.font(), size: 100)
        let tracked = try Picture.Text("AVA B\nAV", font: Self.font(), size: 100, tracking: 0.05)
        #expect(tracked.lines.map(\.width) == zip(plain.lines, [4.0, 1.0]).map { $0.width + $1 * 5 })
        #expect(Self.origins(tracked) == [[0, 0], [55, 0], [115, 0], [182, 0], [217, 0], [0, 110], [55, 110]])
        #expect(tracked.glyphs.map(\.advance) == plain.glyphs.map(\.advance))
        #expect(tracked.glyphs.map(\.outline) == plain.glyphs.map(\.outline))
        let tight = try Picture.Text("AVA B", font: Self.font(), size: 50, tracking: -0.1)
        #expect(Tests.close(tight.width, try Picture.Text("AVA B", font: Self.font(), size: 50).width - 4 * 5))
        #expect(throws: Picture.Text.Error.tracking) { try Picture.Text("A", font: Self.font(), size: 10, tracking: .nan) }
        #expect(throws: Picture.Text.Error.tracking) { try Picture.Text("A", font: Self.font(), size: 10, tracking: .infinity) }
    }

    @Test
    func `Tracking counts toward the measure a line breaks at`() throws {
        #expect(try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320).lines.map(\.glyphs.count) == [6, 2])
        let text = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320, tracking: 0.05)
        #expect(text.lines.map(\.glyphs.count) == [3, 3, 2])
        #expect(text.lines.map(\.width) == [145, 145, 145])
        let slight = try Picture.Text("BB BB BB", font: Self.font(), size: 100, measure: 320, tracking: 0.01)
        #expect(slight.lines.map(\.glyphs.count) == [6, 2])
        #expect(slight.lines[0].width == 314)
    }

    @Test
    func `Tabular figures share the widest digit's advance, centred in it, and are not kerned`() throws {
        let font = Self.typeset()
        let proportional = try Picture.Text("10", font: font, size: 100)
        #expect(proportional.glyphs.map(\.advance) == [40, 60])
        #expect(Self.origins(proportional) == [[0, 0], [35, 0]])
        let tabular = try Picture.Text("1028", font: font, size: 100, figures: .tabular)
        #expect(tabular.metrics.figure == 60)
        #expect(tabular.glyphs.map(\.advance) == [60, 60, 60, 60])
        #expect(Self.origins(tabular) == [[0, 0], [60, 0], [120, 0], [180, 0]])
        #expect(Self.corners(tabular.glyphs[0].outline) == [[[10, 0], [30, 0], [30, -70], [10, -70], [10, 0]]])
        #expect(Self.corners(tabular.glyphs[1].outline) == [[[0, 0], [50, 0], [50, -70], [0, -70], [0, 0]]])
        #expect(Self.corners(tabular.glyphs[3].outline) == [[[2.5, 0], [47.5, 0], [47.5, -70], [2.5, -70], [2.5, 0]]])
        let letters = try Picture.Text("AV", font: font, size: 100, figures: .tabular)
        #expect(Self.origins(letters) == [[0, 0], [50, 0]])
    }

    @Test
    func `A tabular number's width depends only on how many digits it has`() throws {
        let font = Self.typeset()
        let numbers = ["1111", "0000", "1010", "8018", "0101", "9999"]
        let tabular = try numbers.map { number throws(Picture.Text.Error) in try Picture.Text(number, font: font, size: 37, figures: .tabular).width }
        #expect(Set(tabular).count == 1)
        #expect(Tests.close(tabular[0], 4 * 0.6 * 37))
        let proportional = try numbers.map { number throws(Picture.Text.Error) in try Picture.Text(number, font: font, size: 37).width }
        #expect(Set(proportional).count > 1)
        let tracked = try numbers.map { number throws(Picture.Text.Error) in
            try Picture.Text(number, font: font, size: 37, tracking: 0.08, figures: .tabular).width
        }
        #expect(Set(tracked).count == 1)
    }

    @Test
    func `The size fitting a measure sets the widest line to that measure`() throws {
        let font = Self.typeset()
        let cases: [(string: String, tracking: Double, figures: Picture.Text.Figures)] = [
            ("AVA B", 0, .proportional), ("AVA B\nAV", 0.05, .proportional), ("1018 Hx", -0.02, .tabular),
        ]
        for (string, tracking, figures) in cases {
            let text = try Picture.Text(string, font: font, size: 31, tracking: tracking, figures: figures)
            for measure in [100.0, 523.25, 1920] {
                let size = text.size(fitting: measure)
                let fitted = try Picture.Text(string, font: font, size: size, tracking: tracking, figures: figures)
                #expect(Tests.close(fitted.width, measure, within: 1e-9 * measure))
            }
        }
        let text = try Picture.Text("AVA B", font: font, size: 100)
        #expect(text.size(fitting: 1000, maximum: 120) == 120)
        #expect(Tests.close(text.size(fitting: text.width, maximum: 120), 100))
        #expect(try Picture.Text("", font: font, size: 100).size(fitting: 50, maximum: 80) == 80)
        #expect(try Picture.Text(" ", font: font, size: 100).size(fitting: 50) == .infinity)
    }

    /// The vertical extent of a path under a group's transform.
    static func extent(of element: Picture.Element, _ path: Picture.Plane.Path) -> (top: Double, bottom: Double)? {
        guard case .group(let group) = element, let box = path.transformed(by: group.transform).boundingBox else { return nil }
        return (box.lly.underlying, box.ury.underlying)
    }

    @Test
    func `A line put at half its cap height has its capitals' top and bottom equidistant from the point`() throws {
        let fill = Picture.Shape.Fill(.solid(.white))
        let point = Tests.at(320, 180)
        for os2 in [nil, Self.os2()] {
            let text = try Picture.Text("HxH", font: Self.typeset(os2: os2), size: 48)
            let capital = text.glyphs[0].path
            let placed = text.placed(fill, at: point, level: .cap(0.5))
            let extent = try #require(Self.extent(of: placed, capital))
            #expect(Tests.close(point[1] - extent.top, extent.bottom - point[1]))
            #expect(Tests.close(extent.bottom - extent.top, 0.7 * 48))
            let small = try #require(Self.extent(of: text.placed(fill, at: point, level: .ex(0.5)), text.glyphs[1].path))
            #expect(Tests.close(point[1] - small.top, small.bottom - point[1]))
            let top = try #require(Self.extent(of: text.placed(fill, at: point, level: .cap(1)), capital))
            #expect(Tests.close(top.top, point[1]))
            let base = try #require(Self.extent(of: text.placed(fill, at: point), capital))
            #expect(Tests.close(base.bottom, point[1]))
            #expect(text.centered(fill, at: point) == placed)
        }
    }

    @Test
    func `A block of lines is centred between the first line's capitals and the last baseline`() throws {
        let fill = Picture.Shape.Fill(.solid(.white))
        let text = try Picture.Text("H\nAx\nH", font: Self.typeset(), size: 100, leading: 90)
        let point = Tests.at(0, 200)
        let block = text.centered(fill, at: point)
        let first = try #require(Self.extent(of: block, text.glyphs[0].path))
        let final = try #require(text.glyphs.last)
        let last = try #require(Self.extent(of: block, final.path))
        #expect(Tests.close(point[1] - first.top, last.bottom - point[1]))
        #expect(Tests.close(last.bottom - first.top, 70 + 180))
        let lowercase = text.centered(fill, at: point, top: .ex(1))
        let small = try #require(Self.extent(of: lowercase, text.glyphs[2].path))
        let end = try #require(Self.extent(of: lowercase, final.path))
        #expect(Tests.close((small.top - 90) + end.bottom, 2 * point[1]))
    }
}
