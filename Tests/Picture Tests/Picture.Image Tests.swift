import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A picture kept as an image is drawn once, at a scale, through a renderer` {}
}

extension `Picture Tests`.`A picture kept as an image is drawn once, at a scale, through a renderer` {
    typealias Tests = `Picture Tests`

    static let grey = Tests.pixel(0.25, 0.25, 0.25, 0.5)

    /// A renderer that draws nothing of the picture and puts one grey over every pixel it is given.
    static let stub = Picture.Renderer(render: { (_: borrowing Picture, raster: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) in
        raster = raster.map { grey.composited(over: $0, operator: .sourceOver, blend: .normal, coverage: 1) }
    })

    static func rectangle(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Picture.Plane.Rectangle {
        Picture.Plane.Rectangle(llx: .init(x), lly: .init(y), urx: .init(x + width), ury: .init(y + height))
    }

    @Test
    func `The raster has scale pixels to a unit, rounded up, and starts transparent`() throws {
        let image = try Picture.Image([Tests.shape(4, .white)], in: Self.rectangle(3, -2, 2.5, 1), scale: 4, through: Self.stub)
        #expect(image.raster.width == 10)
        #expect(image.raster.height == 4)
        #expect(image.raster.pixels.allSatisfy { $0 == Self.grey })
        let ragged = try Picture.Image(.empty, in: Self.rectangle(0, 0, 2.1, 0.2), scale: 3, through: Self.stub)
        #expect(ragged.raster.width == 7)
        #expect(ragged.raster.height == 1)
    }

    @Test
    func `The placement puts the raster's first corner at the rectangle's and a pixel at one part in scale`() throws {
        let image = try Picture.Image(.empty, in: Self.rectangle(3, -2, 2.5, 1), scale: 4, through: Self.stub)
        #expect(image.placement == Picture.Transform(rows: [[0.25, 0, 3], [0, 0.25, -2]]))
        #expect(image.sampling == .bilinear)
        #expect(image.edge == .constant(.transparent))
        #expect(Tests.close(image.pixel(at: Tests.at(4, -1.5)), Self.grey))
        #expect(image.pixel(at: Tests.at(2.5, -1.5)) == .transparent)
        #expect(image.pixel(at: Tests.at(6, -1.5)) == .transparent)
    }

    @Test
    func `Samples do not change the raster's size`() throws {
        let image = try Picture.Image(.empty, in: Self.rectangle(0, 0, 5, 3), scale: 2, samples: 3, through: Self.stub)
        #expect(image.raster.width == 10)
        #expect(image.raster.height == 6)
        #expect(image.raster.pixels.allSatisfy { Tests.close($0, Self.grey) })
    }

    @Test
    func `A rectangle with no area and a scale that is not positive and finite are unsupported`() {
        for (rectangle, scale) in [
            (Self.rectangle(0, 0, 0, 3), 1.0), (Self.rectangle(0, 0, 3, 0), 1.0), (Self.rectangle(0, 0, -1, 3), 1.0),
            (Self.rectangle(0, 0, 3, 3), 0.0), (Self.rectangle(0, 0, 3, 3), -2.0), (Self.rectangle(0, 0, 3, 3), .infinity),
            (Self.rectangle(0, 0, 3, 3), .nan), (Self.rectangle(0, 0, .infinity, 3), 1.0), (Self.rectangle(0, 0, 3, 3), 1e12),
        ] {
            #expect(throws: Picture.Renderer.Error.unsupported) {
                try Picture.Image(.empty, in: rectangle, scale: scale, through: Self.stub)
            }
        }
    }

    @Test
    func `The renderer's own failure is the image's`() {
        #expect(throws: Picture.Renderer.Error.absent) {
            try Picture.Image(.empty, in: Self.rectangle(0, 0, 3, 3), scale: 1, through: .absent)
        }
    }
}
