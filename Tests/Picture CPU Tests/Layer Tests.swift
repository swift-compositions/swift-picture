import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws a layer on a sheet of its own and composites the sheet as one` {}
}

extension `Picture CPU Tests`.`A renderer draws a layer on a sheet of its own and composites the sheet as one` {
    typealias Tests = `Picture CPU Tests`

    static let backdrop = Tests.pixel(0.2, 0.4, 0.6, 1)

    @Test
    func `Each pixel of the sheet goes onto the pixel behind through the layer's own composite`() throws {
        let content: Picture = [
            Tests.fill(Tests.rectangle(0, 0, 2, 1), Tests.translucent),
            Tests.fill(Tests.rectangle(1, 0, 2, 1), Tests.red),
        ]
        let sheet = try Tests.drawn(content, on: Tests.canvas(4, 1))
        for blend in [BlendMode.normal, .multiply, .screen, .difference, .hue] {
            for `operator` in Compositing.Operator.allCases {
                let layer = Picture.Layer(content, opacity: 0.75, blend: blend, operator: `operator`)
                let raster = try Tests.drawn([.layer(layer)], on: Tests.canvas(4, 1, Self.backdrop))
                #expect(raster.pixels == sheet.pixels.map { layer.composited($0, over: Self.backdrop) })
            }
        }
    }

    @Test
    func `Shapes inside a layer see only the sheet, never what is behind the layer`() throws {
        let inner = Picture.Layer([Tests.fill(Tests.rectangle(0, 0, 2, 1), Tests.red)], operator: .sourceIn)
        let alone = try Tests.drawn([.layer(inner)], on: Tests.canvas(2, 1, Self.backdrop))
        let isolated = try Tests.drawn([.layer(.init([.layer(inner)]))], on: Tests.canvas(2, 1, Self.backdrop))
        #expect(alone.pixels == [Tests.red.pixel, Tests.red.pixel])
        #expect(isolated.pixels == [Self.backdrop, Self.backdrop])
    }

    @Test
    func `An operator that clears where the sheet is empty clears every pixel of the raster inside the clip`() throws {
        let copy = Picture.Layer([Tests.fill(Tests.rectangle(1, 0, 1, 1), Tests.red)], operator: .copy)
        let everywhere = try Tests.drawn([.layer(copy)], on: Tests.canvas(4, 1, Self.backdrop))
        #expect(everywhere.pixels == [.transparent, Tests.red.pixel, .transparent, .transparent])
        let clipped = try Tests.drawn([.group(.init([.layer(copy)], clip: .init(Tests.rectangle(0, 0, 2.5, 1))))], on: Tests.canvas(4, 1, Self.backdrop))
        #expect(clipped.pixels == [.transparent, Tests.red.pixel, Self.backdrop.interpolated(to: .transparent, at: 0.5), Self.backdrop])
    }

    @Test
    func `A plain layer draws as its content would`() throws {
        let content: Picture = [Tests.fill(Tests.polygon([Tests.at(0.3, 0.2), Tests.at(3.6, 1.1), Tests.at(1.2, 2.8)]), Tests.translucent)]
        let backdrop = Tests.canvas(4, 3, Self.backdrop)
        #expect(Tests.close(try Tests.drawn([.layer(.init(content))], on: backdrop), try Tests.drawn(content, on: backdrop)))
    }
}
