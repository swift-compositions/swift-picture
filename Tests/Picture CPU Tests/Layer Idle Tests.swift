import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests`.`A renderer draws a layer on a sheet of its own and composites the sheet as one` {
    @Test
    func `A layer of opacity 0 that keeps the backdrop is not drawn at all`() throws {
        let backdrop = Tests.pixel(0.1, 0.2, 0.3, 1)
        let sheared = Picture.Group(
            [.layer(Picture.Layer([Tests.fill(Tests.rectangle(2, 2, 4, 4), Tests.red)], effects: [.blur(.init(deviation: 2))]))],
            transform: Picture.Transform(rows: [[1, 0.5, 0], [0, 1, 0]])
        )
        let costly: Picture = [.group(sheared)]
        #expect(throws: Picture.Renderer.Error.unsupported) { try Tests.drawn(costly, on: Tests.canvas(10, 10, backdrop)) }
        for operation in [Compositing.Operator.sourceOver, .lighter, .destinationOut, .xor] {
            let idle: Picture = [.layer(Picture.Layer(costly, opacity: 0, operator: operation))]
            let raster = try Tests.drawn(idle, on: Tests.canvas(10, 10, backdrop))
            #expect(raster == Tests.canvas(10, 10, backdrop))
        }
        let cleared = try Tests.drawn([.layer(Picture.Layer([Tests.fill(Tests.rectangle(0, 0, 2, 2), Tests.red)], opacity: 0, operator: .copy))], on: Tests.canvas(4, 4, backdrop))
        #expect(Tests.at(cleared, 0, 0) == .transparent)
        let faint = Picture.Layer([Tests.fill(Tests.rectangle(1, 1, 5, 5), Tests.red)], effects: [.blur(.init(deviation: 1))], opacity: 0)
        let plain = try Tests.drawn([Tests.fill(Tests.rectangle(0, 0, 3, 3), Tests.blue)], on: Tests.canvas(8, 8, backdrop))
        let with = try Tests.drawn([Tests.fill(Tests.rectangle(0, 0, 3, 3), Tests.blue), .layer(faint)], on: Tests.canvas(8, 8, backdrop))
        #expect(plain == with)
    }
}
