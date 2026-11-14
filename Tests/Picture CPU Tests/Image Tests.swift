import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A picture kept as an image shows the picture where it stood` {}
}

extension `Picture CPU Tests`.`A picture kept as an image shows the picture where it stood` {
    typealias Tests = `Picture CPU Tests`

    static let picture: Picture = [
        Tests.fill(Tests.rectangle(0, 0, 9, 7), Tests.blue),
        Tests.fill(Tests.polygon([Tests.at(1.3, 0.7), Tests.at(7.6, 2.1), Tests.at(3.2, 5.8)]), Tests.translucent),
        .layer(.init([Tests.fill(Tests.rectangle(4, 3, 3, 2), Tests.red)], effects: [.blur(.init(deviation: 0.8))])),
    ]

    static func part(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Picture.Plane.Rectangle {
        Picture.Plane.Rectangle(llx: .init(x), lly: .init(y), urx: .init(x + width), ury: .init(y + height))
    }

    @Test
    func `At scale one its raster is the picture's own pixels inside the rectangle`() throws {
        let whole = try Tests.drawn(Self.picture, on: Tests.canvas(9, 7))
        let image = try Picture.Image(Self.picture, in: Self.part(2, 1, 5, 4), scale: 1, through: Tests.renderer)
        #expect(Tests.raster(of: image).width == 5)
        #expect(Tests.raster(of: image).height == 4)
        for (x, y) in Tests.positions(5, 4) {
            #expect(Tests.close(Tests.at(Tests.raster(of: image), x, y), Tests.at(whole, x + 2, y + 1)))
        }
    }

    @Test
    func `Drawn as a paint it puts the part back where it stood and nothing elsewhere`() throws {
        let whole = try Tests.drawn(Self.picture, on: Tests.canvas(9, 7))
        let image = try Picture.Image(Self.picture, in: Self.part(2, 1, 5, 4), scale: 1, sampling: .nearest, through: Tests.renderer)
        let placed: Picture = [.shape(.init(Tests.rectangle(0, 0, 9, 7), fill: .init(.image(image))))]
        let raster = try Tests.drawn(placed, on: Tests.canvas(9, 7))
        for (x, y) in Tests.positions(9, 7) {
            let inside = (2..<7).contains(x) && (1..<5).contains(y)
            #expect(Tests.close(Tests.at(raster, x, y), inside ? Tests.at(whole, x, y) : .transparent))
        }
    }

    @Test
    func `At a larger scale it is the picture drawn that much larger`() throws {
        let image = try Picture.Image(Self.picture, in: Self.part(2, 1, 5, 4), scale: 3, through: Tests.renderer)
        let enlarged: Picture = [.group(.init(Self.picture, transform: .init(rows: [[3, 0, -6], [0, 3, -3]])))]
        #expect(Tests.raster(of: image) == (try Tests.drawn(enlarged, on: Tests.canvas(15, 12))))
        #expect(image.placement == Matrix<3, 3, Double>(Picture.Transform(rows: [[1.0 / 3, 0, 2], [0, 1.0 / 3, 1]])))
    }

    @Test
    func `With samples every pixel is the mean of its square of a finer drawing`() throws {
        let image = try Picture.Image(Self.picture, in: Self.part(2, 1, 5, 4), scale: 1, samples: 2, through: Tests.renderer)
        let fine = try Picture.Image(Self.picture, in: Self.part(2, 1, 5, 4), scale: 2, through: Tests.renderer)
        for (x, y) in Tests.positions(5, 4) {
            let four = [(0, 0), (1, 0), (0, 1), (1, 1)].map { Tests.at(Tests.raster(of: fine), 2 * x + UInt($0.0), 2 * y + UInt($0.1)) }
            let mean = Tests.pixel(
                four.reduce(0) { $0 + $1.color.red } / 4,
                four.reduce(0) { $0 + $1.color.green } / 4,
                four.reduce(0) { $0 + $1.color.blue } / 4,
                four.reduce(0) { $0 + $1.alpha } / 4
            )
            #expect(Tests.close(Tests.at(Tests.raster(of: image), x, y), mean))
        }
    }

    @Test
    func `A sprite between pixel centres is lost at one sample and kept by several`() throws {
        let white = Picture.Color(red: 1, green: 1, blue: 1)
        let speck: Picture = [.sprites(.init([.init(center: Tests.at(1.02, 1.02), radius: 0.2, color: white)], profile: .hard))]
        let coarse = try Picture.Image(speck, in: Self.part(0, 0, 2, 2), scale: 1, through: Tests.renderer)
        #expect(Tests.raster(of: coarse).pixels.allSatisfy { $0 == .transparent })
        let fine = try Picture.Image(speck, in: Self.part(0, 0, 2, 2), scale: 1, samples: 8, through: Tests.renderer)
        #expect(Tests.raster(of: fine).pixels.reduce(0) { $0 + $1.alpha } > 0.05)
    }

    @Test
    func `It is the same image on one thread and on several`() throws {
        let one = try Picture.Image(Self.picture, in: Self.part(0, 0, 9, 7), scale: 40, samples: 2, through: .cpu(threads: 1))
        let four = try Picture.Image(Self.picture, in: Self.part(0, 0, 9, 7), scale: 40, samples: 2, through: .cpu(threads: 4))
        #expect(one == four)
    }

    @Test
    func `A picture that cannot be drawn fails and gives no image`() {
        let sheared: Picture = [
            .group(.init([.layer(.init([Tests.fill(Tests.rectangle(0, 0, 2, 2), Tests.red)], effects: [.blur(.init(deviation: 2))]))], transform: .init(rows: [[1, 1, 0], [0, 1, 0]])))
        ]
        #expect(throws: Picture.Renderer.Error.unsupported) {
            try Picture.Image(sheared, in: Self.part(0, 0, 4, 4), scale: 1, through: Tests.renderer)
        }
    }
}
