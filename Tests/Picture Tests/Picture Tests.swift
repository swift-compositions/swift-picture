import Picture
import Testing

enum `Picture Tests` {}

extension `Picture Tests` {
    typealias Pixel = Picture.Pixel

    /// The pixels an image holds; none for an image that is still a drawing.
    static func raster(of image: Picture.Image) -> Raster<Picture.Pixel> {
        guard case .pixels(let raster) = image.content else { return Raster(width: .zero, height: .zero, repeating: .transparent) }
        return raster
    }

    /// The source of an image that is still a drawing, nil for one that holds its pixels.
    static func source(of image: Picture.Image) -> Picture.Image.Source? {
        guard case .drawing(let source) = image.content else { return nil }
        return source
    }

    static func at(_ x: Double, _ y: Double) -> Picture.Plane.Point<2> { .init([x, y]) }

    static func close(_ a: Double, _ b: Double, within tolerance: Double = 1e-9) -> Bool {
        abs(a - b) <= tolerance
    }

    static func close(_ a: Picture.Plane.Point<2>, _ b: Picture.Plane.Point<2>, within tolerance: Double = 1e-9) -> Bool {
        close(a[0], b[0], within: tolerance) && close(a[1], b[1], within: tolerance)
    }

    static func close(_ a: Float, _ b: Float, within tolerance: Float = 1e-6) -> Bool {
        abs(a - b) <= tolerance
    }

    static func close(_ a: Pixel, _ b: Pixel, within tolerance: Float = 1e-6) -> Bool {
        close(a.color.red, b.color.red, within: tolerance) && close(a.color.green, b.color.green, within: tolerance)
            && close(a.color.blue, b.color.blue, within: tolerance) && close(a.alpha, b.alpha, within: tolerance)
    }

    static func pixel(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float) -> Pixel {
        Pixel(color: .init(red: red, green: green, blue: blue), alpha: alpha)
    }

    static func square(_ side: Double) -> Picture.Plane.Path {
        Picture.Plane.Path(subpaths: [
            .init(
                startPoint: at(0, 0),
                segments: [
                    .line(.init(start: at(0, 0), end: at(side, 0))),
                    .line(.init(start: at(side, 0), end: at(side, side))),
                    .line(.init(start: at(side, side), end: at(0, side))),
                ],
                isClosed: true
            )
        ])
    }

    static func shape(_ side: Double, _ color: Picture.Color) -> Picture.Element {
        .shape(Picture.Shape(square(side), fill: .init(.solid(color))))
    }

    static func sendable<Value: Sendable & Hashable>(_: Value.Type) -> Bool { true }
}

extension `Picture Tests` {
    @Suite
    struct `A picture is a list of elements drawn in order` {}
}

extension `Picture Tests`.`A picture is a list of elements drawn in order` {
    typealias Tests = `Picture Tests`

    @Test
    func `Appending lists this picture's elements and then the other's, and the empty picture is neutral`() {
        let red = Tests.shape(1, .init(red: 1, green: 0, blue: 0))
        let green = Tests.shape(2, .init(red: 0, green: 1, blue: 0))
        let blue = Tests.shape(3, .init(red: 0, green: 0, blue: 1))
        let first: Picture = [red, green]
        let second: Picture = [blue]
        #expect(first.appending(second).elements == [red, green, blue])
        #expect(second.appending(first).elements == [blue, red, green])
        #expect(first.appending(.empty) == first)
        #expect(Picture.empty.appending(first) == first)
        #expect(Picture.empty.elements.isEmpty)
        #expect(first.appending(second).appending(first) == first.appending(second.appending(first)))
    }

    @Test
    func `Pictures are equal when their elements are, in order, and equal pictures hash alike`() {
        let red = Tests.shape(1, .init(red: 1, green: 0, blue: 0))
        let green = Tests.shape(1, .init(red: 0, green: 1, blue: 0))
        #expect(Picture([red, green]) == Picture([red, green]))
        #expect(Picture([red, green]) != Picture([green, red]))
        #expect(Picture([red, green]).hashValue == Picture([red, green]).hashValue)
        #expect(Set([Picture([red, green]), Picture([red, green]), Picture([green, red])]).count == 2)
        let nested = Picture([.group(.init([red], transform: .translation(Vector([1, 2]))))])
        #expect(nested != Picture([.group(.init([red], transform: .translation(Vector([1, 3]))))]))
        #expect(nested != Picture([.layer(.init([red]))]))
    }

    @Test
    func `Every part of a picture is a sendable, hashable value`() {
        #expect(Tests.sendable(Picture.self))
        #expect(Tests.sendable(Picture.Element.self))
        #expect(Tests.sendable(Picture.Shape.self))
        #expect(Tests.sendable(Picture.Paint.self))
        #expect(Tests.sendable(Picture.Image.self))
        #expect(Tests.sendable(Picture.Group.self))
        #expect(Tests.sendable(Picture.Layer.self))
        #expect(Tests.sendable(Picture.Effect.self))
        #expect(Tests.sendable(Picture.Sprites.self))
        #expect(Tests.sendable(Picture.Scene.self))
        #expect(Tests.sendable(Picture.Text.self))
        #expect(Tests.sendable(Picture.Color.self))
        #expect(Tests.sendable(Picture.Gradient.self))
        #expect(Tests.sendable(Picture.Clip.self))
        #expect(Tests.sendable(Picture.Camera.self))
        #expect(Tests.sendable(Picture.Glass.self))
        #expect(Tests.sendable(Picture.Glass.Pane.self))
        #expect(Tests.sendable(Picture.Scene.Camera.self))
        #expect(Tests.sendable(Picture.Scene.Model.self))
    }

    @Test
    func `A group and a layer start from the identity, no clip, no effects, full opacity, normal and source over`() {
        let group = Picture.Group([])
        #expect(group.transform == .identity)
        #expect(group.clip == nil)
        let layer = Picture.Layer([])
        #expect(layer.effects.isEmpty)
        #expect(layer.opacity == 1)
        #expect(layer.blend == .normal)
        #expect(layer.operator == .sourceOver)
        #expect(Picture.Clip(Tests.square(1)).rule == .nonzero)
        #expect(Picture.Shape.Fill(.solid(.black)).rule == .nonzero)
    }
}

extension `Picture Tests` {
    @Suite
    struct `A layer is composited as one` {}
}

extension `Picture Tests`.`A layer is composited as one` {
    typealias Tests = `Picture Tests`

    @Test
    func `A plain layer puts its sheet over what is behind`() {
        let sheet = Tests.pixel(0.25, 0, 0, 0.5)
        let backdrop = Tests.pixel(0, 0, 1, 1)
        #expect(Picture.Layer([]).composited(sheet, over: backdrop) == Tests.pixel(0.25, 0, 0.5, 1))
        #expect(Picture.Layer([]).composited(sheet, over: .transparent) == sheet)
    }

    @Test
    func `Opacity multiplies the sheet before it is composited`() {
        let sheet = Tests.pixel(1, 0, 0, 1)
        let backdrop = Tests.pixel(0, 0, 1, 1)
        #expect(Picture.Layer([], opacity: 0.5).composited(sheet, over: backdrop) == Tests.pixel(0.5, 0, 0.5, 1))
        #expect(Picture.Layer([], opacity: 0).composited(sheet, over: backdrop) == backdrop)
    }

    @Test
    func `Light added with lighter adds its colour without a limit and holds alpha at one`() {
        let lighter = Picture.Layer([], operator: .lighter)
        let sheet = Tests.pixel(0.5, 0.25, 0, 0.5)
        #expect(lighter.composited(sheet, over: Tests.pixel(0.125, 0, 0.25, 0.25)) == Tests.pixel(0.625, 0.25, 0.25, 0.75))
        #expect(lighter.composited(sheet, over: Tests.pixel(0.75, 1, 0.25, 1)) == Tests.pixel(1.25, 1.25, 0.25, 1))
        #expect(lighter.composited(Tests.pixel(2, 2, 2, 1), over: Tests.pixel(0, 0, 0, 0.75)) == Tests.pixel(2, 2, 2, 1))
        // Put onto an opaque pixel afterwards, a sheet lit like that hides it and no more.
        let lit = lighter.composited(Tests.pixel(0.5, 0.5, 0.5, 1), over: Tests.pixel(0.5, 0.5, 0.5, 1))
        #expect(Picture.Layer([]).composited(lit, over: Tests.pixel(1, 1, 1, 1)) == Tests.pixel(1, 1, 1, 1))
    }

    @Test
    func `The operator and the blend mode are the layer's`() {
        let sheet = Tests.pixel(0.5, 0.25, 0, 0.5)
        let backdrop = Tests.pixel(0.25, 0.25, 0.25, 1)
        #expect(Picture.Layer([], operator: .lighter).composited(sheet, over: backdrop) == Tests.pixel(0.75, 0.5, 0.25, 1))
        #expect(Picture.Layer([], operator: .copy).composited(sheet, over: backdrop) == sheet)
        let multiplied = Picture.Layer([], blend: .multiply).composited(Tests.pixel(0.5, 0.5, 0.5, 1), over: Tests.pixel(0.5, 1, 0, 1))
        #expect(multiplied == Tests.pixel(0.25, 0.5, 0, 1))
        #expect(
            Picture.Layer([], opacity: 0.5, blend: .screen, operator: .sourceAtop).composited(sheet, over: backdrop)
                == sheet.composited(over: backdrop, operator: .sourceAtop, blend: .screen, coverage: 0.5)
        )
    }
}

extension `Picture Tests` {
    @Suite
    struct `Glow and a pane over a backdrop are compositions` {}
}

extension `Picture Tests`.`Glow and a pane over a backdrop are compositions` {
    typealias Tests = `Picture Tests`

    @Test
    func `A glow is the picture and, on top, a blurred copy that adds its light`() {
        let picture: Picture = [Tests.shape(4, .white)]
        let glowing = picture.glow(deviation: 3, strength: 0.5)
        #expect(
            glowing.elements == [
                Tests.shape(4, .white),
                .layer(.init(picture, effects: [.blur(.init(deviation: 3))], opacity: 0.5, operator: .lighter)),
            ]
        )
        #expect(
            picture.glow(deviation: 2).elements.last
                == .layer(.init(picture, effects: [.blur(.init(deviation: 2))], opacity: 1, operator: .lighter))
        )
    }

    @Test
    func `A pane is the picture and, on top, inside the clip, the picture again under the effects, copied`() {
        let picture: Picture = [Tests.shape(4, .white), Tests.shape(2, .black)]
        let clip = Picture.Clip(Tests.square(1), rule: .evenodd)
        let effects: [Picture.Effect] = [.blur(.init(deviation: 5)), .pixelation(.init(width: 2, height: 2))]
        #expect(
            picture.backdrop(effects, clip: clip).elements == [
                Tests.shape(4, .white),
                Tests.shape(2, .black),
                .group(.init([.layer(.init(picture, effects: effects, operator: .copy))], clip: clip)),
            ]
        )
    }
}

extension `Picture Tests` {
    @Suite
    struct `A stroke is the outline swift-geometry gives` {}
}

extension `Picture Tests`.`A stroke is the outline swift-geometry gives` {
    typealias Tests = `Picture Tests`

    @Test
    func `The outline of a stroke is the path stroked with its pen`() throws {
        let pen = Picture.Plane.Path.Stroke(width: 2, join: .miter(limit: 4), cap: .square)
        let stroke = Picture.Shape.Stroke(.solid(.black), pen: pen)
        let path = Tests.square(10)
        let outline = try stroke.outline(of: path, tolerance: 0.01)
        #expect(try outline == path.stroked(pen, tolerance: 0.01))
        #expect(!outline.isEmpty)
        #expect(outline.contains(Tests.at(10.5, 5), rule: .nonzero))
        #expect(!outline.contains(Tests.at(5, 5), rule: .nonzero))
        let round = Picture.Shape.Stroke(.solid(.black), pen: .init(width: 2, join: .round, cap: .round))
        #expect(try round.outline(of: path, tolerance: 0.01) != outline)
    }

    @Test
    func `A pen the geometry refuses fails with its error`() {
        let stroke = Picture.Shape.Stroke(.solid(.black), pen: .init(width: -1, join: .round, cap: .round))
        #expect(throws: Picture.Plane.Path.Error.width) { try stroke.outline(of: Tests.square(10), tolerance: 0.01) }
        let sharp = Picture.Shape.Stroke(.solid(.black), pen: .init(width: 1, join: .miter(limit: 0.5), cap: .butt))
        #expect(throws: Picture.Plane.Path.Error.limit) { try sharp.outline(of: Tests.square(10), tolerance: 0.01) }
        let fine = Picture.Shape.Stroke(.solid(.black), pen: .init(width: 1, join: .round, cap: .butt))
        #expect(throws: Picture.Plane.Path.Error.tolerance) { try fine.outline(of: Tests.square(10), tolerance: 0) }
    }
}
