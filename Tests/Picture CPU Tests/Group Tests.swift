import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws a group's content moved, straight onto what is behind, limited by the clip` {}
}

extension `Picture CPU Tests`.`A renderer draws a group's content moved, straight onto what is behind, limited by the clip` {
    typealias Tests = `Picture CPU Tests`

    static let content: Picture = [
        Tests.fill(Tests.polygon([Tests.at(0.2, 0.1), Tests.at(3.7, 0.6), Tests.at(1.4, 2.9)]), Tests.translucent),
        Tests.fill(Tests.rectangle(0.5, 0.5, 1.25, 1), Tests.red),
    ]

    @Test
    func `The content's point p is drawn at the transform applied to p`() throws {
        let moved = try Tests.drawn([.group(.init(Self.content, transform: .translation(Vector([3, 1]))))], on: Tests.canvas(8, 5))
        let shifted = Picture(
            Self.content.elements.map { element in
                guard case .shape(let shape) = element else { return element }
                return .shape(.init(shape.path.transformed(by: .translation(Vector([3, 1]))), fill: shape.fill))
            }
        )
        #expect(moved == (try Tests.drawn(shifted, on: Tests.canvas(8, 5))))
    }

    @Test
    func `A group inside a group draws at the outer transform times the inner`() throws {
        let outer = Picture.Transform(rows: [[0.8, -0.6, 4], [0.6, 0.8, 0.5]])
        let inner = Picture.Transform(rows: [[1.5, 0, -1], [0.25, 1, 2]])
        let nested = try Tests.drawn([.group(.init([.group(.init(Self.content, transform: inner))], transform: outer))], on: Tests.canvas(9, 9))
        let once = try Tests.drawn([.group(.init(Self.content, transform: outer.multiplied(by: inner)))], on: Tests.canvas(9, 9))
        let reversed = try Tests.drawn([.group(.init(Self.content, transform: inner.multiplied(by: outer)))], on: Tests.canvas(9, 9))
        #expect(Tests.close(nested, once))
        #expect(!Tests.close(nested, reversed))
    }

    @Test
    func `A group with the identity and no clip draws exactly as its elements would`() throws {
        let backdrop = Tests.canvas(5, 4, Tests.blue.pixel)
        #expect(try Tests.drawn([.group(.init(Self.content))], on: backdrop) == Tests.drawn(Self.content, on: backdrop))
    }

    @Test
    func `Where the clip covers a share c of a pixel, the pixel ends as what was there plus c times the change`() throws {
        let backdrop = Tests.blue.pixel
        let clip = Picture.Clip(Tests.rectangle(0, 0, 1.5, 1))
        let raster = try Tests.drawn(
            [.group(.init([Tests.fill(Tests.rectangle(0, 0, 3, 1), Tests.translucent)], clip: clip))],
            on: Tests.canvas(3, 1, backdrop)
        )
        let changed = Tests.translucent.pixel.composited(over: backdrop)
        #expect(Tests.at(raster, 0, 0) == changed)
        #expect(Tests.at(raster, 1, 0) == backdrop.interpolated(to: changed, at: 0.5))
        #expect(Tests.at(raster, 2, 0) == backdrop)
    }

    @Test
    func `The clip is in the content's space and moves with it, and clips inside clips multiply`() throws {
        let backdrop = Tests.blue.pixel
        let inner = Picture.Group([Tests.fill(Tests.rectangle(-5, -5, 20, 20), Tests.red)], clip: .init(Tests.rectangle(0, 0, 4, 0.25)))
        let outer = Picture.Group([.group(inner)], transform: .init(rows: [[1, 0, 0], [0, 2, 0]]), clip: .init(Tests.rectangle(0, 0, 0.75, 1)))
        let raster = try Tests.drawn([.group(outer)], on: Tests.canvas(2, 2, backdrop))
        let changed = Tests.red.pixel
        #expect(Tests.at(raster, 0, 0) == backdrop.interpolated(to: changed, at: 0.375))
        #expect(Tests.at(raster, 1, 0) == backdrop)
        #expect(Tests.at(raster, 0, 1) == backdrop)
    }

    @Test
    func `A transform that squashes the plane draws nothing`() throws {
        let backdrop = Tests.canvas(4, 4, Tests.blue.pixel)
        let squashed = Picture.Transform(rows: [[1, 2, 0], [2, 4, 0]])
        #expect(try Tests.drawn([.group(.init(Self.content, transform: squashed))], on: backdrop) == backdrop)
    }
}
