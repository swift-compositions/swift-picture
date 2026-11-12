import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A renderer is a value that draws a picture into a raster` {}
}

extension `Picture Tests`.`A renderer is a value that draws a picture into a raster` {
    typealias Tests = `Picture Tests`
    typealias Canvas = Raster<Picture.Pixel>

    static let picture: Picture = [Tests.shape(2, .white), Tests.shape(1, .black)]

    /// A stand-in renderer: it writes one pixel per element along the first row.
    static let counting = Picture.Renderer(render: { (picture: borrowing Picture, raster: inout Canvas) throws(Picture.Renderer.Error) in
        guard picture.elements.count <= Int(clamping: raster.width) else { throw .unsupported }
        picture.elements.indices.forEach { index in
            raster[x: Ordinal(UInt(index)), y: .zero] = Tests.pixel(1, 1, 1, 1)
        }
    })

    /// Draws through swift-renderer's protocol alone, knowing nothing of pictures.
    static func draw<Operation: Renderer.`Protocol`>(
        _ input: borrowing Operation.Input,
        with operation: borrowing Operation,
        into context: inout Operation.Context
    ) throws(Operation.Failure) {
        try operation.render(input, into: &context)
    }

    static func blank() -> Canvas {
        Canvas(width: 3, height: 2, repeating: .transparent)
    }

    @Test
    func `The closure takes the picture borrowed and the raster inout, and fails with the renderer's error`() throws {
        var raster = Self.blank()
        try Self.counting.render(Self.picture, &raster)
        #expect(raster.pixels.map(\.alpha) == [1, 1, 0, 0, 0, 0])
        var small = Canvas(width: 1, height: 1, repeating: .transparent)
        #expect(throws: Picture.Renderer.Error.unsupported) { try Self.counting.render(Self.picture, &small) }
        #expect(small.pixels == [.transparent])
    }

    @Test
    func `It is a renderer of swift-renderer, and the macro's labelled method stands beside the protocol's`() throws {
        var first = Self.blank()
        try Self.draw(Self.picture, with: Self.counting, into: &first)
        var second = Self.blank()
        try Self.counting.render(Self.picture, into: &second)
        var third = Self.blank()
        try Self.counting.render(picture: Self.picture, raster: &third)
        #expect(first.pixels.map(\.alpha) == [1, 1, 0, 0, 0, 0])
        #expect(second == first)
        #expect(third == first)
        var small = Canvas(width: 1, height: 1, repeating: .transparent)
        #expect(throws: Picture.Renderer.Error.unsupported) { try Self.draw(Self.picture, with: Self.counting, into: &small) }
    }

    @Test
    func `The absent renderer draws nothing and fails with absent`() throws {
        var raster = Canvas(width: 2, height: 1, repeating: Tests.pixel(0, 0, 1, 1))
        #expect(throws: Picture.Renderer.Error.absent) { try Picture.Renderer.absent.render(Self.picture, into: &raster) }
        #expect(throws: Picture.Renderer.Error.absent) { try Picture.Renderer.absent.render(Picture.empty, into: &raster) }
        #expect(raster.pixels == [Tests.pixel(0, 0, 1, 1), Tests.pixel(0, 0, 1, 1)])
    }

    @Test
    func `An unimplemented renderer fails with the witness's own error, naming the operation`() {
        var raster = Self.blank()
        var failure: Picture.Renderer.Error?
        do throws(Picture.Renderer.Error) {
            try Picture.Renderer.unimplemented().render(Self.picture, into: &raster)
        } catch {
            failure = error
        }
        guard case .unimplemented(let error) = failure else {
            Issue.record("An unimplemented renderer fails with .unimplemented, not \(String(describing: failure))")
            return
        }
        #expect(error.witness == "Renderer")
        #expect(error.operation.hasPrefix("render"))
        #expect(raster == Self.blank())
    }

    @Test
    func `A renderer and its errors are sendable, and errors compare and hash`() {
        func sendable<Value: Sendable>(_: Value.Type) -> Bool { true }
        #expect(sendable(Picture.Renderer.self))
        #expect(sendable(Picture.Renderer.Error.self))
        #expect(Picture.Renderer.Error.absent != .unsupported)
        #expect(Picture.Renderer.Error.path(.width) == .path(.width))
        #expect(Picture.Renderer.Error.path(.width) != .path(.limit))
        #expect(Set([Picture.Renderer.Error.absent, .absent, .unsupported, .path(.width), .path(.width)]).count == 3)
    }
}
