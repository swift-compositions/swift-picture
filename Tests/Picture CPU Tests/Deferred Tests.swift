import Picture
import Picture_CPU
import Synchronization
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `Building a picture draws nothing: a renderer draws each distinct source once, when it first needs it` {}
}

extension `Picture CPU Tests`.`Building a picture draws nothing: a renderer draws each distinct source once, when it first needs it` {
    typealias Tests = `Picture CPU Tests`

    /// How many times drawings were drawn.
    final class Count: Sendable {
        let drawn = Mutex(0)

        var value: Int { drawn.withLock { $0 } }
    }

    /// A small drawing of one level of grey that counts how often it is drawn; the count is not part of its value.
    struct Counted: Picture.Image.Drawing {
        let level: Float
        let count: Count

        static func == (first: Self, second: Self) -> Bool { first.level == second.level }

        func hash(into hasher: inout Hasher) { hasher.combine(level) }

        func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
            count.drawn.withLock { $0 += 1 }
            return Raster(width: 6, height: 5, repeating: Picture.Color(red: level, green: level, blue: level).pixel)
        }
    }

    static let rectangle = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 24, ury: 20)

    /// A picture of three counted images, two of them the same drawing, placed apart.
    static func scene(_ count: Count) -> Picture {
        Picture(
            [0.4, 0.95, 0.4].enumerated().map { (index: Int, level: Double) -> Picture.Element in
                let placement = Picture.Transform(rows: [[1, 0, Double(index) * 7], [0, 1, Double(index) * 4]])
                let image = Picture.Image(Counted(level: Float(level), count: count), placement: placement)
                return .fill(Tests.rectangle(Double(index) * 7, Double(index) * 4, 6, 5), .image(image))
            }
        )
    }

    /// Every recipe built on kept images, over the scene, by name.
    static func recipes(_ count: Count) -> [String: Picture] {
        let scene = scene(count)
        return [
            "scene": scene,
            "kept": [.image(scene, in: rectangle, scale: 1.5, samples: 2)],
            "bloom": scene.bloom(in: rectangle, deviation: 3),
            "rays": scene.rays(from: Tests.at(12, 10), in: rectangle, length: 0.3, streaks: 3),
            "glow": scene.glow(deviation: 1.5),
        ]
    }

    @Test
    func `Building, comparing and hashing pictures that keep images draws nothing`() {
        let count = Count()
        let first = Self.recipes(count)
        let second = Self.recipes(count)
        #expect(first == second)
        #expect(first.mapValues(\.hashValue) == second.mapValues(\.hashValue))
        #expect(Set(Array(first.values) + Array(second.values)).count == first.count)
        #expect(count.value == 0)
    }

    @Test(arguments: [1, 3, 8] as [Cardinal])
    func `Drawing twice through one renderer draws each distinct source once, on any number of threads`(threads: Cardinal) throws {
        for recipe in Self.recipes(Count()).keys.sorted() {
            let count = Count()
            let picture = Self.recipes(count)[recipe] ?? .empty
            let renderer = Picture.Renderer.cpu(threads: threads)
            var first = Tests.canvas(24, 20)
            try renderer.render(picture, into: &first)
            var second = Tests.canvas(24, 20)
            try renderer.render(picture, into: &second)
            #expect(first == second)
            #expect(count.value == 2, "recipe \(recipe) on \(threads) threads drew its two distinct sources \(count.value) times")
        }
    }

    @Test
    func `An image of pixels is equal to one of equal pixels, and its hash is made once for all its copies`() {
        let raster = Raster(width: 40, height: 30, repeating: Picture.Color(red: 0.2, green: 0.6, blue: 0.9).pixel)
        let image = Picture.Image(raster)
        let copy = image
        let apart = Picture.Image(Raster(width: 40, height: 30, repeating: Picture.Color(red: 0.2, green: 0.6, blue: 0.9).pixel))
        #expect(image == copy && image == apart)
        #expect(image.hashValue == copy.hashValue && image.hashValue == apart.hashValue)
        var changed = apart
        changed.raster = Raster(width: 40, height: 30, repeating: Picture.Color(red: 0.2, green: 0.6, blue: 0.8).pixel)
        #expect(changed != image)
        #expect(changed.raster != image.raster)
    }
}
