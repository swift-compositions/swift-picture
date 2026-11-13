import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests`.`A picture kept as an image shows the picture where it stood` {
    @Test
    func `A kept picture fills an area wider than its rectangle by its edge rule`() throws {
        let part = Self.part(2, 1, 5, 4)
        let wide = Self.part(-3, -2, 20, 14)
        for edge in [Raster<Picture.Pixel>.Edge.mirror, .wrap, .extend] {
            let element = Picture.Element.image(Self.picture, in: part, scale: 1, sampling: .nearest, edge: edge, filling: wide)
            let raster = try Tests.drawn([element], on: Tests.canvas(14, 9))
            let image = try Picture.Image(Self.picture, in: part, scale: 1, sampling: .nearest, edge: edge, through: Tests.renderer)
            for (x, y) in Tests.positions(14, 9) {
                #expect(
                    Tests.close(Tests.at(raster, x, y), image.pixel(at: Tests.at(Double(x) + 0.5, Double(y) + 0.5))),
                    "\(edge) \(x) \(y) \(Tests.at(raster, x, y)) \(image.pixel(at: Tests.at(Double(x) + 0.5, Double(y) + 0.5)))"
                )
            }
            #expect(Tests.at(raster, 0, 0).alpha > 0)
        }
        let narrow = try Tests.drawn([.image(Self.picture, in: part, scale: 1, edge: .mirror)], on: Tests.canvas(14, 9))
        #expect(Tests.at(narrow, 0, 0) == .transparent)
    }

    @Test
    func `A kept picture fitted onto four corners is seen in perspective`() throws {
        var marked: Picture = [Tests.fill(Tests.rectangle(0, 0, 20, 20), .white)]
        marked.elements.append(Tests.fill(Tests.rectangle(9, 9, 2, 2), Picture.Color(red: 0, green: 0, blue: 0)))
        let corners: InlineArray<4, Picture.Plane.Point<2>> = [Tests.at(10, 10), Tests.at(70, 10), Tests.at(60, 50), Tests.at(20, 50)]
        let element = try Picture.Element.image(marked, in: Self.part(0, 0, 20, 20), scale: 4, onto: corners)
        let raster = try Tests.drawn([element], on: Tests.canvas(80, 60))
        var (sum, x, y) = (0.0, 0.0, 0.0)
        for (column, row) in Tests.positions(80, 60) {
            let pixel = Tests.at(raster, column, row)
            let dark = Double(pixel.alpha - pixel.color.red)
            guard dark > 0.05 else { continue }
            sum += dark
            x += dark * (Double(column) + 0.5)
            y += dark * (Double(row) + 0.5)
        }
        // The diagonals of the corners cross at (40, 34); their mean is (40, 30).
        #expect(abs(x / sum - 40) < 0.5)
        #expect(abs(y / sum - 34) < 0.5)
        #expect(Tests.at(raster, 5, 5) == .transparent)
        #expect(Tests.close(Tests.at(raster, 40, 20), Picture.Color.white.pixel))
        #expect(throws: Matrix<3, 3, Double>.Error.singular) {
            try Picture.Element.image(marked, in: Self.part(0, 0, 20, 20), scale: 1, onto: [Tests.at(0, 0), Tests.at(1, 1), Tests.at(2, 2), Tests.at(0, 5)])
        }
    }
}
