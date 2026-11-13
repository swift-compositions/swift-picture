import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `Bloom and rays add the light of a picture's bright parts, and a gradient paints its colours` {}
}

extension `Picture CPU Tests`.`Bloom and rays add the light of a picture's bright parts, and a gradient paints its colours` {
    typealias Tests = `Picture CPU Tests`

    static let width: UInt = 48
    static let height: UInt = 32
    static let frame = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 48, ury: 32)

    /// A grey ground, a white bar, a saturated red square, a dim blue one and a translucent wedge.
    static let scene: Picture = [
        Tests.fill(Tests.rectangle(0, 0, 48, 32), Picture.Color(gray: 0.2)),
        Tests.fill(Tests.rectangle(6, 5, 3, 20), .white),
        Tests.fill(Tests.rectangle(20, 8, 8, 8), Tests.red),
        Tests.fill(Tests.rectangle(34, 18, 7, 7), Picture.Color(red: 0.1, green: 0.2, blue: 0.5)),
        Tests.fill(Tests.polygon([Tests.at(12, 30), Tests.at(30, 22), Tests.at(40, 31)]), Tests.translucent),
    ]

    /// The same picture with nothing brighter than a third in linear light.
    static let dim: Picture = [
        Tests.fill(Tests.rectangle(0, 0, 48, 32), Picture.Color(gray: 0.2)),
        Tests.fill(Tests.rectangle(20, 8, 8, 8), Picture.Color(red: 0.5, green: 0.3, blue: 0.1)),
        Tests.fill(Tests.rectangle(34, 18, 7, 7), Picture.Color(red: 0.1, green: 0.2, blue: 0.5)),
    ]

    static func drawn(_ picture: Picture) throws -> Tests.Canvas {
        try Tests.drawn(picture, on: Tests.canvas(width, height, Tests.pixel(0, 0, 0, 1)))
    }

    /// The picture kept as an image of the frame and drawn as that image.
    static func kept(_ picture: Picture) -> Picture {
        [.fill(Tests.rectangle(0, 0, 48, 32), .image(Picture.Image(picture, in: frame, scale: 1)))]
    }

    static func lighter(_ a: Tests.Canvas, than b: Tests.Canvas) -> Bool {
        zip(a.pixels, b.pixels).allSatisfy { a, b in
            a.color.red >= b.color.red && a.color.green >= b.color.green && a.color.blue >= b.color.blue && a.alpha >= b.alpha
        }
    }

    @Test
    func `A picture with nothing above the threshold blooms to itself, kept`() throws {
        let kept = try Self.drawn(Self.kept(Self.dim))
        #expect(try Self.drawn(Self.dim.bloom(in: Self.frame)) == kept)
        #expect(try Self.drawn(Self.dim.rays(from: Tests.at(24, 16), in: Self.frame)) == kept)
        #expect(Tests.close(kept, try Self.drawn(Self.dim), within: 1e-5))
    }

    @Test
    func `No octaves, no length or no strength give the kept picture alone`() {
        #expect(Self.scene.bloom(in: Self.frame, octaves: 0) == Self.kept(Self.scene))
        #expect(Self.scene.bloom(in: Self.frame, strength: 0) == Self.kept(Self.scene))
        #expect(Self.scene.rays(from: Tests.at(3, 3), in: Self.frame, length: 0) == Self.kept(Self.scene))
        #expect(Self.scene.rays(from: Tests.at(3, 3), in: Self.frame, streaks: 0) == Self.kept(Self.scene))
    }

    @Test(arguments: [Picture.Effect.Threshold(), .init(level: 0, knee: 0), .init(level: 0.9, knee: 0.05)])
    func `Bloom and rays never darken a pixel, and bright parts add light`(threshold: Picture.Effect.Threshold) throws {
        let kept = try Self.drawn(Self.kept(Self.scene))
        let bloomed = try Self.drawn(Self.scene.bloom(in: Self.frame, threshold: threshold, deviation: 6))
        let rayed = try Self.drawn(Self.scene.rays(from: Tests.at(4, 4), in: Self.frame, threshold: threshold))
        #expect(Self.lighter(bloomed, than: kept))
        #expect(Self.lighter(rayed, than: kept))
        #expect(bloomed != kept)
        #expect(Tests.at(bloomed, 11, 15).color.red > Tests.at(kept, 11, 15).color.red)
    }

    @Test
    func `Bloom is the kept picture with its thresholded light, blurred at each octave, added`() throws {
        let threshold = Picture.Effect.Threshold(level: 0.4, knee: 0.3)
        let image = Picture.Image(Self.scene, in: Self.frame, scale: 1)
        let keptElement = Picture.Element.fill(Tests.rectangle(0, 0, 48, 32), .image(image))
        let light: Picture = Picture(
            [8.0, 4].map { deviation in
                .layer(Picture.Layer([keptElement], effects: [.threshold(threshold), .blur(.init(deviation: deviation))], opacity: 0.5, operator: .lighter))
            }
        )
        let spread = Picture.Element.fill(Tests.rectangle(0, 0, 48, 32), .image(Picture.Image(light, in: Self.frame, scale: 0.5)))
        let expected: Picture = [keptElement, .layer(Picture.Layer([spread], opacity: 1.5, operator: .lighter))]
        #expect(Self.scene.bloom(in: Self.frame, threshold: threshold, deviation: 8, octaves: 2, strength: 1.5) == expected)
    }

    @Test
    func `Bloom and rays are drawn the same every time and on every number of threads`() throws {
        let picture = Self.scene.bloom(in: Self.frame, deviation: 5).rays(from: Tests.at(40, 4), in: Self.frame, length: 0.6)
        var one = Tests.canvas(Self.width, Self.height)
        try Picture.Renderer.cpu(threads: 1).render(picture, into: &one)
        for threads: Cardinal in [1, 3, 8] {
            var raster = Tests.canvas(Self.width, Self.height)
            try Picture.Renderer.cpu(threads: threads).render(picture, into: &raster)
            #expect(raster == one)
        }
    }

    @Test
    func `A threshold in a layer changes each pixel of the sheet by the threshold`() throws {
        let threshold = Picture.Effect.Threshold(level: 0.3, knee: 0.2)
        let sheet = try Tests.drawn(Self.scene, on: Tests.canvas(Self.width, Self.height))
        let drawn = try Tests.drawn([.layer(.init(Self.scene, effects: [.threshold(threshold)]))], on: Tests.canvas(Self.width, Self.height))
        #expect(drawn.pixels == sheet.pixels.map(threshold.pixel))
    }

    @Test
    func `A source that another source names is drawn into the frame as the images drawn beforehand would be`() throws {
        let picture = Self.scene.bloom(in: Self.frame, deviation: 5)
        let renderer = Picture.Renderer.cpu
        let inner = try Picture.Image(Self.scene, in: Self.frame, scale: 1).drawn(through: renderer)
        let drawnFirst = Picture(
            picture.elements.map { element in
                guard case .shape(var shape) = element, case .image = shape.fill?.paint else { return element }
                shape.fill = .init(.image(inner))
                return .shape(shape)
            }
        )
        #expect(try Self.drawn(picture) == Self.drawn(drawnFirst))
    }

    @Test(arguments: [0.0, 0.13, 0.31, 0.5, 0.62, 0.88, 1.0])
    func `A gradient's colour at a parameter is what the renderer paints there`(parameter: Double) throws {
        let gradient = Picture.Gradient([
            .init(offset: 0, color: Picture.Color(red: 1, green: 0.7, blue: 0.3, alpha: 0.9)),
            .init(offset: 0.25, color: Picture.Color(red: 0.1, green: 0.2, blue: 0.9, alpha: 0.5)),
            .init(offset: 0.75, color: .white),
            .init(offset: 1, color: Picture.Color(red: 0.2, green: 0.9, blue: 0.4)),
        ])
        let painted = try Tests.drawn(
            [.fill(Tests.rectangle(0, 0, 101, 1), .linear(.init(from: Tests.at(0.5, 0), to: Tests.at(100.5, 0), gradient)))],
            on: Tests.canvas(101, 1)
        )
        let column = UInt((parameter * 100).rounded())
        #expect(Tests.close(Tests.at(painted, column, 0), gradient.color(at: Float(Double(column) / 100)).pixel, within: 1e-5))
    }
}
