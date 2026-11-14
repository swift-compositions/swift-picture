import Picture
import Standard_Library_Extensions
import Testing

@Suite struct `Picture Written Tests` {
    static func labels(_ value: Any) -> [String] {
        Mirror(reflecting: value).children.map { $0.label ?? "" }
    }

    static let corners: [Picture.Plane.Point<2>] = [.init([1, 2]), .init([5, 2.5]), .init([2, 6])]

    static var path: Picture.Plane.Path {
        let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
            Picture.Plane.Path.Segment.line(.init(start: start, end: end))
        }
        return Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
    }

    @Test func `every stored property of a type that writes itself is written`() throws {
        // A property added to one of these fails here until its `write(into:)` writes it too.
        let shape = Picture.Shape(Self.path, fill: .init(.solid(.white)))
        #expect(Self.labels(Picture()) == ["elements"])
        #expect(Self.labels(shape) == ["path", "fill", "stroke"])
        #expect(Self.labels(try #require(shape.fill)) == ["paint", "rule"])
        #expect(Self.labels(Picture.Shape.Stroke(.solid(.white), pen: .init(width: 1, join: .round, cap: .round))) == ["paint", "pen"])
        #expect(Self.labels(Self.path) == ["subpaths"])
        #expect(Self.labels(Self.path.subpaths[0]) == ["startPoint", "segments", "isClosed"])
        guard case .line(let line) = Self.path.subpaths[0].segments[0] else {
            Issue.record("a line")
            return
        }
        #expect(Self.labels(line) == ["start", "end"])
        #expect(Self.labels(Self.corners[0]) == ["position"])
        #expect(Self.labels(Picture.Color.white) == ["red", "green", "blue", "alpha"])
        let tile = Raster<Picture.Pixel>(width: 2, height: 2, repeating: .transparent)
        #expect(Self.labels(Picture.Image(tile)) == ["stored", "placement", "sampling", "edge"])
        #expect(Self.labels(Picture.Gradient([.init(offset: 0, color: .white)])) == ["stops", "ramp"])
        #expect(Self.labels(Picture.Gradient.Stop(offset: 0, color: .white)) == ["offset", "color"])
        #expect(Self.labels(tile) == ["width", "height", "storage"])
    }

    @Test func `pictures that differ in any written part have different bytes`() throws {
        let shape = Picture.Shape(Self.path, fill: .init(.solid(.white)))
        var moved = Self.path
        moved.subpaths[0].isClosed = false
        let tile = Raster<Picture.Pixel>(width: 2, height: 2, repeating: .transparent)
        var image = Picture.Image(tile)
        image.edge = .wrap
        let pictures: [Picture] = [
            [.shape(shape)],
            [.shape(Picture.Shape(moved, fill: .init(.solid(.white))))],
            [.shape(Picture.Shape(Self.path, fill: .init(.solid(.black))))],
            [.shape(Picture.Shape(Self.path, fill: .init(.solid(.white), rule: .evenodd)))],
            [.shape(Picture.Shape(Self.path, stroke: .init(.solid(.white), pen: .init(width: 1, join: .round, cap: .round))))],
            [.fill(Self.path, .image(Picture.Image(tile)))],
            [.fill(Self.path, .image(image))],
            [.group(Picture.Group([.shape(shape)]))],
            [.fill(Self.path, .linear(.init(from: Self.corners[0], to: Self.corners[1], Picture.Gradient(evenly: [.white, .black]))))],
            [.fill(Self.path, .linear(.init(from: Self.corners[0], to: Self.corners[1], Picture.Gradient(evenly: [.white, .clear]))))],
        ]
        let bytes = try pictures.map { try #require(Mirror.bytes(of: $0)) }
        #expect(Set(bytes).count == pictures.count)
        #expect(Mirror.bytes(of: Picture([.shape(shape)])) == bytes[0])
    }
}
