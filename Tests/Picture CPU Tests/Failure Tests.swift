import Picture
import Picture_CPU
import Synchronization
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A drawing's own failure reaches whoever drew it unchanged, and nothing is kept for it` {}
}

extension `Picture CPU Tests`.`A drawing's own failure reaches whoever drew it unchanged, and nothing is kept for it` {
    typealias Tests = `Picture CPU Tests`

    /// Why the pixels of a drawing did not arrive.
    enum Missing: Swift.Error, Hashable {
        case gone(Int)
        case late
    }

    /// Whether drawings fail, and how often they were asked to draw; neither is part of a drawing's value.
    final class Supply: Sendable {
        let failing = Mutex(true)
        let asked = Mutex(0)

        var count: Int { asked.withLock { $0 } }
    }

    /// A drawing of one level of grey whose pixels come from a supply that may fail to give them.
    struct Supplied: Picture.Image.Drawing {
        let level: Float
        let supply: Supply

        static func == (first: Self, second: Self) -> Bool { first.level == second.level }

        func hash(into hasher: inout Hasher) { hasher.combine(level) }

        func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
            supply.asked.withLock { $0 += 1 }
            if supply.failing.withLock({ $0 }) { throw .drawing(.init(Missing.gone(7))) }
            return Raster(width: 6, height: 5, repeating: Picture.Color(red: level, green: level, blue: level).pixel)
        }
    }

    static let failure = Picture.Renderer.Error.drawing(.init(Missing.gone(7)))

    static let rectangle = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 12, ury: 10)

    /// A picture painting with the supplied drawing, over a grey ground.
    static func scene(_ supply: Supply) -> Picture {
        let image = Picture.Image(Supplied(level: 0.7, supply: supply), placement: .init(rows: [[1, 0, 3], [0, 1, 2]]))
        return [
            Tests.fill(Tests.rectangle(0, 0, 12, 10), Picture.Color(gray: 0.2)),
            .group(.init([.layer(.init([.fill(Tests.rectangle(3, 2, 6, 5), .image(image))], opacity: 0.9))])),
        ]
    }

    /// Every way a picture shows the supplied drawing, by name: directly, and kept as an image of a part.
    static func pictures(_ supply: Supply) -> [String: Picture] {
        ["scene": scene(supply), "kept": [.image(scene(supply), in: rectangle, scale: 2, samples: 2)]]
    }

    @Test
    func `A failure is its error with its type: equal exactly when the errors are, hashed and described as they are`() {
        let failure = Picture.Image.Failure(Missing.gone(7))
        #expect(failure == Picture.Image.Failure(Missing.gone(7)))
        #expect(failure.hashValue == Picture.Image.Failure(Missing.gone(7)).hashValue)
        #expect(failure != Picture.Image.Failure(Missing.gone(8)))
        #expect(failure != Picture.Image.Failure(Missing.late))
        #expect(failure != Picture.Image.Failure(Picture.Renderer.Error.unsupported))
        #expect(failure.error(as: Missing.self) == .gone(7))
        #expect(failure.error(as: Picture.Renderer.Error.self) == nil)
        #expect(failure.description == String(describing: Missing.gone(7)))
        #expect(Picture.Renderer.Error.drawing(failure) != .unsupported)
    }

    @Test
    func `The failure comes back unchanged from the drawing, its source and its image drawn alone`() {
        let supply = Supply()
        let drawing = Supplied(level: 0.7, supply: supply)
        #expect(throws: Self.failure) { try drawing.raster(through: Tests.renderer) }
        #expect(throws: Self.failure) { try Picture.Image.Source(drawing).raster(through: Tests.renderer) }
        #expect(throws: Self.failure) { try Picture.Image(drawing, placement: Picture.Transform.identity).drawn(through: Tests.renderer) }
        #expect(throws: Self.failure) {
            try Picture.Image(Self.scene(supply), in: Self.rectangle, scale: 2, through: Tests.renderer)
        }
    }

    @Test(arguments: [1, 4] as [Cardinal])
    func `A renderer drawing a picture that shows the drawing fails with it unchanged and leaves the raster as it was`(threads: Cardinal) {
        for (name, picture) in Self.pictures(Supply()) {
            let renderer = Picture.Renderer.cpu(threads: threads)
            var raster = Tests.canvas(12, 10, Tests.pixel(0.1, 0.2, 0.3, 1))
            #expect(throws: Self.failure, "\(name)") { try renderer.render(picture, into: &raster) }
            #expect(raster == Tests.canvas(12, 10, Tests.pixel(0.1, 0.2, 0.3, 1)), "\(name)")
        }
    }

    @Test(arguments: [1, 4] as [Cardinal])
    func `Nothing is kept for a drawing that failed: an equal drawing asked for later is drawn, and shown`(threads: Cardinal) throws {
        for name in Self.pictures(Supply()).keys.sorted() {
            let supply = Supply()
            let picture = Self.pictures(supply)[name] ?? .empty
            let renderer = Picture.Renderer.cpu(threads: threads)
            var raster = Tests.canvas(12, 10)
            #expect(throws: Self.failure, "\(name)") { try renderer.render(picture, into: &raster) }
            supply.failing.withLock { $0 = false }
            supply.asked.withLock { $0 = 0 }
            let later = Self.pictures(supply)[name] ?? .empty
            try renderer.render(later, into: &raster)
            #expect(supply.count == 1, "\(name)")
            var fresh = Tests.canvas(12, 10)
            try Picture.Renderer.cpu(threads: threads).render(later, into: &fresh)
            #expect(raster == fresh, "\(name)")
            #expect(raster != Tests.canvas(12, 10), "\(name)")
        }
    }
}
