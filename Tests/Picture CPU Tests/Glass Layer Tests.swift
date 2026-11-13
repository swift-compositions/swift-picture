import Numeric
import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `Glass in a layer reads the picture beneath the layer` {}
}

extension `Picture CPU Tests`.`Glass in a layer reads the picture beneath the layer` {
    typealias Tests = `Picture CPU Tests`

    /// Black and white stripes four pixels wide under a red square.
    static let backdrop: [Picture.Element] = [Tests.fill(Tests.rectangle(0, 0, 80, 60), .black)]
        + stride(from: 0.0, to: 80, by: 8).map { Tests.fill(Tests.rectangle($0, 0, 4, 60), .white) }
        + [Tests.fill(Tests.rectangle(30, 20, 14, 14), Tests.red)]

    static let glass = Picture.Glass(
        tint: Picture.Color(red: 0.2, green: 0.4, blue: 1, alpha: 0.2),
        light: .init(direction: Vector([-0.3, 0.9, 0.4]), rim: 0.8, width: 1.5),
        refraction: .init(index: 1.5, distance: 8, abbe: 20),
        frost: 2,
        shadows: [.init(color: .init(red: 0, green: 0, blue: 0, alpha: 0.5), softness: 3, x: 0, y: 3)]
    )

    static let pane = Picture.Element.pane(
        Picture.Glass.Pane(.rectangle(.init(llx: 12, lly: 10, urx: 68, ury: 48), radius: 14), glass: glass, thickness: 8, rim: 10)
    )

    static func drawn(_ elements: [Picture.Element]) throws -> Tests.Canvas {
        try Tests.drawn(Picture(backdrop + elements), on: Tests.canvas(80, 60))
    }

    @Test
    func `A pane at opacity 0 is no pane, at 1 the pane, and between the backdrop mixed that far to the pane`() throws {
        let bare = try Self.drawn([])
        let whole = try Self.drawn([Self.pane])
        #expect(!Tests.close(bare, whole, within: 0.05))
        #expect(Tests.close(try Self.drawn([.layer(Picture.Layer([Self.pane], opacity: 0))]), bare, within: 1e-6))
        #expect(Tests.close(try Self.drawn([.layer(Picture.Layer([Self.pane], opacity: 1))]), whole, within: 1e-5))
        for share: Float in [0.25, 0.5, 0.8] {
            let faded = try Self.drawn([.layer(Picture.Layer([Self.pane], opacity: share))])
            for (x, y) in Tests.positions(80, 60) {
                let expected = Tests.at(bare, x, y).interpolated(to: Tests.at(whole, x, y), at: share)
                #expect(Tests.close(Tests.at(faded, x, y), expected, within: 1e-4))
            }
        }
    }

    @Test
    func `A pane in nested layers and groups reads the picture as it stands, layers' content included`() throws {
        let blue = Tests.fill(Tests.rectangle(16, 30, 30, 10), Tests.blue)
        let moved = Picture.Element.group(Picture.Group([Self.pane], transform: .translation(x: 3, y: -2)))
        let flat = try Self.drawn([blue, moved])
        let nested = try Self.drawn([
            .layer(Picture.Layer([blue, .group(Picture.Group([.layer(Picture.Layer([Self.pane]))], transform: .translation(x: 3, y: -2)))]))
        ])
        #expect(Tests.close(nested, flat, within: 1e-5))
        let clipped = try Self.drawn([
            .group(Picture.Group([.layer(Picture.Layer([blue, moved]))], clip: Picture.Clip(Tests.rectangle(-10, -10, 100, 100))))
        ])
        #expect(Tests.close(clipped, flat, within: 1e-5))
    }

    @Test
    func `A body in a layer reads what is beneath the layer, and fades with it`() throws {
        let projection = try Projection<Double>.orthographic(width: 8, height: 6, near: 0, far: 10, depth: .unit)
        let ball = Picture.Scene.Model(
            .sphere(radius: 2, meridians: 32, parallels: 16),
            transform: Matrix(rows: [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, -5], [0, 0, 0, 1]]),
            material: .glass(Self.glass)
        )
        let scene = Picture.Element.scene(Picture.Scene(camera: .init(projection: projection), viewport: .init(llx: 0, lly: 0, urx: 80, ury: 60), models: [ball]))
        let bare = try Self.drawn([])
        let whole = try Self.drawn([scene])
        #expect(!Tests.close(bare, whole, within: 0.05))
        #expect(Tests.close(try Self.drawn([.layer(Picture.Layer([scene]))]), whole, within: 1e-5))
        let half = try Self.drawn([.layer(Picture.Layer([scene], opacity: 0.5))])
        for (x, y) in Tests.positions(80, 60) {
            #expect(Tests.close(Tests.at(half, x, y), Tests.at(bare, x, y).interpolated(to: Tests.at(whole, x, y), at: 0.5), within: 1e-4))
        }
    }
}
