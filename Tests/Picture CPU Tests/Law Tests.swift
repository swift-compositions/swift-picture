import Numeric
import Picture
import Testing

@testable import Picture_CPU

extension `Picture CPU Tests` {
    @Suite
    struct `The CPU renderer keeps, refuses and draws back as its laws say` {}
}

extension `Picture CPU Tests`.`The CPU renderer keeps, refuses and draws back as its laws say` {
    typealias Tests = `Picture CPU Tests`
    typealias Deferred = `Picture CPU Tests`.`Building a picture draws nothing: a renderer draws each distinct source once, when it first needs it`

    @Test
    func `Reading cpu twice gives two renderers that keep nothing for each other`() throws {
        let count = Deferred.Count()
        let picture = Deferred.scene(count)
        var first = Tests.canvas(24, 20)
        try Picture.Renderer.cpu.render(picture, into: &first)
        var second = Tests.canvas(24, 20)
        try Picture.Renderer.cpu.render(picture, into: &second)
        #expect(first == second)
        // Two distinct sources, drawn afresh by each reading.
        #expect(count.value == 4)
    }

    @Test
    func `The store lets the rasters asked for longest ago go first`() throws {
        let count = Deferred.Count()
        func key(_ level: Float) throws -> Picture.Renderer.CPU.Store.Key {
            let image = Picture.Image(Deferred.Counted(level: level, count: count), placement: Picture.Transform.identity)
            return Picture.Renderer.CPU.Store.Key(try #require(image.source))
        }
        let raster = Raster(width: 6, height: 5, repeating: Picture.Pixel.transparent)
        let store = Picture.Renderer.CPU.Store(bound: 70)
        let (a, b, c) = (try key(0.1), try key(0.2), try key(0.3))
        store.keep(raster, for: a)
        store.keep(raster, for: b)
        #expect(store.raster(for: a) != nil)
        store.keep(raster, for: c)
        #expect(store.raster(for: b) == nil)
        #expect(store.raster(for: a) != nil && store.raster(for: c) != nil)
        // A raster larger than the bound is not kept at all.
        store.keep(Raster(width: 9, height: 9, repeating: Picture.Pixel.transparent), for: try key(0.4))
        #expect(store.raster(for: try key(0.4)) == nil)
        #expect(store.raster(for: a) != nil && store.raster(for: c) != nil)
    }

    @Test
    func `A sheet larger than the limit is refused as unsupported, and the raster is left as it was`() {
        // A zoom of amount −2000 reads points two thousand times as far out as they are from its centre.
        let content: Picture = [Tests.fill(Tests.rectangle(-20000, -20000, 40000, 40000), Tests.red)]
        let picture: Picture = [.layer(.init(content, effects: [.zoom(.init(center: Tests.at(4, 4), amount: -2000))]))]
        var raster = Tests.canvas(8, 8, Tests.pixel(0.1, 0.2, 0.3, 1))
        #expect(throws: Picture.Renderer.Error.unsupported) {
            try Picture.Renderer.cpu(threads: 1).render(picture, into: &raster)
        }
        #expect(raster == Tests.canvas(8, 8, Tests.pixel(0.1, 0.2, 0.3, 1)))
    }

    @Test
    func `A grazing read is drawn back toward the point: all the way at a cosine of zero, not at all from the grazing cosine`() throws {
        let projection = try Projection<Double>.orthographic(width: 4, height: 4, near: 0, far: 10, depth: .unit)
        let scene = Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 24, ury: 24), models: [])
        let lens = Picture.Renderer.CPU.Lens(scene, .identity)
        let far = Picture.Renderer.CPU.Far(Picture.Renderer.CPU.Stage(), eyes: [], over: .empty)
        let refraction = Picture.Glass.Refraction(index: 1.5, distance: 4)
        func passage(_ cosine: Double) -> Picture.Renderer.CPU.Passage {
            let sine = (1 - cosine * cosine).squareRoot()
            return Picture.Renderer.CPU.Passage(
                from: Vector([0, 0, -5]),
                normal: Vector([sine, 0, cosine]),
                at: .init(x: 12, y: 12),
                through: refraction,
                plane: -9,
                lens: lens,
                far: far
            )
        }
        let point = Picture.Renderer.CPU.Passage.Read(x: 12, y: 12)
        func same(_ a: Picture.Renderer.CPU.Passage.Read, _ b: Picture.Renderer.CPU.Passage.Read?) -> Bool {
            guard let b else { return false }
            return a.x == b.x && a.y == b.y
        }
        let level = passage(0.5)
        let full = level.read(for: level.index, lens: lens)
        #expect(full.x != point.x)
        #expect(same(full, level.way(within: level.inner, lens: lens).read))
        let edgeOn = passage(0)
        let back = edgeOn.read(for: edgeOn.index, lens: lens)
        #expect(back.x == point.x && back.y == point.y)
        let at = passage(Picture.Renderer.CPU.Passage.grazing)
        #expect(same(at.read(for: at.index, lens: lens), at.way(within: at.inner, lens: lens).read ?? point))
        let half = passage(Picture.Renderer.CPU.Passage.grazing / 2)
        let unbent = half.way(within: half.inner, lens: lens).read ?? point
        let drawn = half.read(for: half.index, lens: lens)
        #expect(abs((drawn.x - point.x) - (unbent.x - point.x) / 2) < 1e-12)
    }

    @Test
    func `Glass shows the hazed picture behind it, and its own tint is not hazed`() throws {
        let projection = try Projection<Double>.orthographic(width: 4, height: 4, near: 0, far: 20, depth: .unit)
        let square = try Mesh(
            vertices: [Point::Point<3, Double>([-3, -3, 0]), Point([3, -3, 0]), Point([3, 3, 0]), Point([-3, 3, 0])],
            faces: [Polygon(0, 1, 2, 3)]
        )
        let color = Picture.Color(red: 0.9, green: 0.4, blue: 0.1)
        let tint = Picture.Color(red: 0.2, green: 0.5, blue: 0.9, alpha: 0.4)
        let haze = Picture.Scene.Haze(Picture.Color(red: 0.6, green: 0.7, blue: 0.8), density: 0.1)
        let scene = Picture.Scene(
            camera: .init(projection: projection),
            viewport: .init(llx: 0, lly: 0, urx: 24, ury: 24),
            models: [
                .init(square, transform: .translation(Vector([0, 0, -8])), material: .flat(color)),
                .init(square, transform: .translation(Vector([0, 0, -3])), material: .glass(.init(bend: 0, tint: tint))),
            ],
            haze: haze
        )
        let raster = try Tests.drawn([.scene(scene)], on: Tests.canvas(24, 24))
        let behind = haze.pixel(color.pixel, at: 8)
        let expected = tint.pixel.composited(over: behind)
        #expect(Tests.close(Tests.at(raster, 12, 12), expected, within: 1e-5))
        #expect(!Tests.close(Tests.at(raster, 12, 12), haze.pixel(expected, at: 3), within: 1e-3))
    }
}
