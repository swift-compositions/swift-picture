import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws a shape's fill first and its stroke on top, the stroke's outline under nonzero` {}
}

extension `Picture CPU Tests`.`A renderer draws a shape's fill first and its stroke on top, the stroke's outline under nonzero` {
    typealias Tests = `Picture CPU Tests`

    static let pen = Picture.Plane.Path.Stroke(width: 1, join: .miter(limit: 4), cap: .butt)

    /// An open path of straight lines through the points in order.
    static func line(_ points: [Picture.Plane.Point<2>]) -> Picture.Plane.Path {
        let sides = zip(points, points.dropFirst()).map { start, end in
            Picture.Plane.Path.Segment.line(.init(start: start, end: end))
        }
        return Picture.Plane.Path(subpaths: [.init(startPoint: points[0], segments: sides, isClosed: false)])
    }

    @Test
    func `The stroke goes over the fill, each by the share of the pixel it covers`() throws {
        let backdrop = Tests.blue.pixel
        let shape = Picture.Shape(Tests.rectangle(1, 1, 2, 2), fill: .init(.solid(Tests.red)), stroke: .init(.solid(Tests.translucent), pen: Self.pen))
        let raster = try Tests.drawn([.shape(shape)], on: Tests.canvas(4, 4, backdrop))
        let filled = Tests.red.pixel.composited(over: backdrop)
        #expect(Tests.close(Tests.at(raster, 1, 1), Tests.translucent.pixel.composited(over: filled, coverage: 0.75)))
        #expect(Tests.close(Tests.at(raster, 0, 0), Tests.translucent.pixel.composited(over: backdrop, coverage: 0.25)))
        #expect(Tests.close(Tests.at(raster, 0, 1), Tests.translucent.pixel.composited(over: backdrop, coverage: 0.5)))
        let reversed = Picture.Shape(Tests.rectangle(1, 1, 2, 2), fill: .init(.solid(Tests.translucent)), stroke: .init(.solid(Tests.red), pen: Self.pen))
        let other = try Tests.drawn([.shape(reversed)], on: Tests.canvas(4, 4, backdrop))
        #expect(!Tests.close(Tests.at(other, 1, 1), Tests.at(raster, 1, 1)))
    }

    @Test
    func `Where pieces of the outline overlap, the stroke covers once`() throws {
        let backdrop = Tests.blue.pixel
        let back = Self.line([Tests.at(0.5, 1.5), Tests.at(3.5, 1.5), Tests.at(1.5, 1.5)])
        let raster = try Tests.drawn([.shape(.init(back, stroke: .init(.solid(Tests.translucent), pen: Self.pen)))], on: Tests.canvas(4, 3, backdrop))
        let once = Tests.translucent.pixel.composited(over: backdrop)
        #expect(Tests.at(raster, 2, 1) == once)
        #expect(Tests.at(raster, 2, 0) == backdrop)
    }

    @Test
    func `A group that scales scales the pen`() throws {
        let stroke = Picture.Shape(Self.line([Tests.at(0, 1), Tests.at(4, 1)]), stroke: .init(.solid(Tests.red), pen: Self.pen))
        let raster = try Tests.drawn([.group(.init([.shape(stroke)], transform: .init(rows: [[1, 0, 0], [0, 2, 0]])))], on: Tests.canvas(4, 4))
        #expect((0..<4).map { Tests.at(raster, 1, $0) } == [.transparent, Tests.red.pixel, Tests.red.pixel, .transparent])
    }

    @Test
    func `A stroke the geometry refuses fails with its error`() {
        for (pen, error) in [
            (Picture.Plane.Path.Stroke(width: -1, join: .round, cap: .round), Picture.Plane.Path.Error.width),
            (Picture.Plane.Path.Stroke(width: 1, join: .miter(limit: 0.5), cap: .round), .limit),
        ] {
            var raster = Tests.canvas(2, 2)
            #expect(throws: Picture.Renderer.Error.path(error)) {
                try Tests.renderer.render([.shape(.init(Tests.rectangle(0, 0, 1, 1), stroke: .init(.solid(.black), pen: pen)))], into: &raster)
            }
            #expect(throws: Picture.Renderer.Error.path(error)) {
                let squashed = Picture.Transform(rows: [[0, 0, 0], [0, 0, 0]])
                try Tests.renderer.render([.group(.init([.shape(.init(Tests.rectangle(0, 0, 1, 1), stroke: .init(.solid(.black), pen: pen)))], transform: squashed))], into: &raster)
            }
        }
    }
}
