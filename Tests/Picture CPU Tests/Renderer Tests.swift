import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `The CPU renderer is the renderer a picture is drawn with` {}
}

extension `Picture CPU Tests`.`The CPU renderer is the renderer a picture is drawn with` {
    typealias Tests = `Picture CPU Tests`

    static let picture: Picture = [
        Tests.fill(Tests.polygon([Tests.at(0.3, 0.2), Tests.at(3.6, 1.1), Tests.at(1.2, 2.8)]), Tests.translucent),
        .group(.init([Tests.fill(Tests.rectangle(0, 0, 4, 3), Tests.red)], clip: .init(Tests.rectangle(2.5, 0.5, 1, 2)))),
    ]

    static let backdrop = Tests.canvas(4, 3, Tests.blue.pixel)

    /// A stand-in renderer: it writes one pixel per element along the first row.
    static let counting = Picture.Renderer(render: { (picture: borrowing Picture, raster: inout Tests.Canvas) throws(Picture.Renderer.Error) in
        picture.elements.indices.forEach { index in
            raster[x: Ordinal(UInt(index)), y: .zero] = Tests.pixel(1, 1, 1, 1)
        }
    })

    @Test
    func `The live, preview and test renderers are the CPU renderer`() throws {
        let expected = try Tests.drawn(Self.picture, on: Self.backdrop)
        for renderer in [Picture.Renderer.liveValue, Picture.Renderer.previewValue, Picture.Renderer.testValue, Witness.Context[Picture.Renderer.self]] {
            var raster = Self.backdrop
            try renderer.render(Self.picture, into: &raster)
            #expect(raster == expected)
        }
        try Witness.Context.withTest { _ in
        } operation: { () throws(Picture.Renderer.Error) in
            var raster = Self.backdrop
            try Witness.Context[Picture.Renderer.self].render(Self.picture, into: &raster)
            #expect(raster == expected)
        }
    }

    @Test
    func `A renderer set with withWitnesses is the one drawn with inside the scope, and only there`() throws {
        var raster = Tests.canvas(3, 2)
        try withWitnesses {
            $0[Picture.Renderer.self] = Self.counting
        } operation: { () throws(Picture.Renderer.Error) in
            try Witness.Context[Picture.Renderer.self].render(Self.picture, into: &raster)
        }
        #expect(raster.pixels.map(\.alpha) == [1, 1, 0, 0, 0, 0])
        var drawn = Self.backdrop
        try Witness.Context[Picture.Renderer.self].render(Self.picture, into: &drawn)
        #expect(drawn == (try Tests.drawn(Self.picture, on: Self.backdrop)))
    }

    @Test
    func `A renderer draws over what is already there, and changes nothing when it fails`() throws {
        let refused = Picture.Element.shape(
            .init(Tests.rectangle(0, 0, 1, 1), stroke: .init(.solid(.black), pen: .init(width: -1, join: .round, cap: .round)))
        )
        var raster = Self.backdrop
        #expect(throws: Picture.Renderer.Error.path(.width)) { try Tests.renderer.render(Self.picture.appending([refused]), into: &raster) }
        #expect(raster == Self.backdrop)
        var inside = Self.backdrop
        #expect(throws: Picture.Renderer.Error.path(.width)) {
            try Tests.renderer.render(Self.picture.appending([.layer(.init([.group(.init([refused]))]))]), into: &inside)
        }
        #expect(inside == Self.backdrop)
    }

    @Test
    func `The same renderer on the same machine gives equal rasters for equal pictures`() throws {
        // One renderer value, and a second picture built apart from the first, equal to it.
        let renderer = Picture.Renderer.cpu(threads: 3)
        let equal = Picture(Self.picture.elements.map { $0 })
        #expect(equal == Self.picture)
        var first = Self.backdrop
        try renderer.render(Self.picture, into: &first)
        var second = Self.backdrop
        try renderer.render(equal, into: &second)
        #expect(first == second)
        #expect(first != Self.backdrop)
    }
}
