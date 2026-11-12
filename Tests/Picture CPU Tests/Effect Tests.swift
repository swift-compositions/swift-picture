import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer applies a layer's effects to the sheet as a picture on the whole plane` {}
}

extension `Picture CPU Tests`.`A renderer applies a layer's effects to the sheet as a picture on the whole plane` {
    typealias Tests = `Picture CPU Tests`

    static let width: UInt = 24
    static let height: UInt = 16
    static let margin: UInt = 40

    /// Content that reaches past every border of the raster: a gradient band, a disc of colour and a
    /// translucent wedge off the left edge.
    static let content: Picture = [
        .shape(
            .init(
                Tests.rectangle(-8, -6, 40, 12),
                fill: .init(
                    .linear(
                        .init(
                            from: Tests.at(-8, 0),
                            to: Tests.at(32, 10),
                            .init([.init(offset: 0, color: Tests.red), .init(offset: 1, color: Tests.translucent)])
                        )
                    )
                )
            )
        ),
        Tests.fill(Tests.polygon([Tests.at(-12, 4), Tests.at(3, 9), Tests.at(-2, 22)]), Tests.translucent),
        Tests.fill(Tests.rectangle(14.5, 7.25, 6, 12), Tests.blue),
    ]

    /// The content drawn on a raster that reaches `margin` pixels past every border, with no effect.
    static func sheet() throws -> Tests.Canvas {
        let moved = Picture([.group(.init(content, transform: .translation(Vector([Double(margin), Double(margin)]))))])
        return try Tests.drawn(moved, on: Tests.canvas(width + 2 * margin, height + 2 * margin))
    }

    /// The sheet at a point of the raster's space, read bilinearly, transparent where nothing was drawn.
    static func read(_ sheet: Tests.Canvas, _ point: Picture.Plane.Point<2>) -> Tests.Pixel {
        sheet.sample(at: Point<2, Double>(x: point[0] + Double(margin), y: point[1] + Double(margin)), .bilinear, edge: .constant(.transparent)) {
            $0.interpolated(to: $1, at: Float($2))
        }
    }

    static func drawn(_ effects: [Picture.Effect]) throws -> Tests.Canvas {
        try Tests.drawn([.layer(.init(content, effects: effects))], on: Tests.canvas(width, height))
    }

    static func centre(_ x: UInt, _ y: UInt) -> Picture.Plane.Point<2> {
        Tests.at(Double(x) + 0.5, Double(y) + 0.5)
    }

    /// Every pixel of the drawn raster against the pixel the law names for its centre.
    static func expect(_ drawn: Tests.Canvas, within tolerance: Float = 1e-5, _ law: (Picture.Plane.Point<2>) -> Tests.Pixel) {
        for (x, y) in Tests.positions(width, height) {
            let expected = law(centre(x, y))
            #expect(Tests.close(Tests.at(drawn, x, y), expected, within: tolerance), "at \(x), \(y)")
        }
    }

    /// The sheet convolved with the Gaussian kernel of a deviation on both axes.
    static func convolved(_ sheet: Tests.Canvas, _ deviation: Float) throws -> Tests.Canvas {
        let kernel = try Tests.Canvas.Kernel<Float>.gaussian(deviation: deviation)
        return sheet.convolved(horizontal: kernel, vertical: kernel, edge: .constant(.transparent)) { $0.interpolated(to: $1, at: $2) }
    }

    /// The sheet smoothed by the cascade of five boxes of a deviation on both axes.
    static func smoothed(_ sheet: Tests.Canvas, _ deviation: Float) throws -> Tests.Canvas {
        let cascade = try Raster<SIMD4<Float>>.Cascade<Float>.gaussian(deviation: deviation, count: 5)
        let lanes = sheet.map { SIMD4($0.color.red, $0.color.green, $0.color.blue, $0.alpha) }
        return lanes.smoothed(horizontal: cascade, vertical: cascade, edge: .constant(.zero)).map { lanes in
            Tests.Pixel(color: .init(red: lanes[0], green: lanes[1], blue: lanes[2]), alpha: lanes[3])
        }
    }

    @Test
    func `A blur below a deviation of 2 is the sheet convolved with the Gaussian, the raster's edge never showing`() throws {
        let blurred = try Self.convolved(try Self.sheet(), 1.5)
        Self.expect(try Self.drawn([.blur(.init(deviation: 1.5))])) { Self.read(blurred, $0) }
        #expect(try Self.drawn([.blur(.init(deviation: 0))]) == Self.drawn([]))
        #expect(try Self.drawn([.blur(.init(deviation: -1))]) == Self.drawn([]))
    }

    @Test
    func `From a deviation of 2 a blur is a cascade of five boxes, within 0.064 of the Gaussian times the brightest channel`() throws {
        let sheet = try Self.sheet()
        let brightest = sheet.pixels.reduce(Float(0)) { Swift.max($0, $1.color.red, $1.color.green, $1.color.blue, $1.alpha) }
        for deviation: Float in [2, 2.5, 7] {
            let smoothed = try Self.smoothed(sheet, deviation)
            let drawn = try Self.drawn([.blur(.init(deviation: Double(deviation)))])
            Self.expect(drawn) { Self.read(smoothed, $0) }
            let exact = try Self.convolved(sheet, deviation)
            Self.expect(drawn, within: 0.064 * brightest) { Self.read(exact, $0) }
        }
    }

    @Test
    func `Pixelation, kaleidoscope, displacement and swirl read the sheet at the point their source names`() throws {
        let sheet = try Self.sheet()
        let pixelation = Picture.Effect.Pixelation(origin: Tests.at(1, -2), width: 3, height: 5)
        Self.expect(try Self.drawn([.pixelation(pixelation)])) { Self.read(sheet, pixelation.source(of: $0)) }
        let kaleidoscope = Picture.Effect.Kaleidoscope(center: Tests.at(30, -3), segments: 5, rotation: .init(0.3))
        Self.expect(try Self.drawn([.kaleidoscope(kaleidoscope)])) { Self.read(sheet, kaleidoscope.source(of: $0)) }
        let displacement = Picture.Effect.Displacement(seed: .init(7, 11), frequency: 0.1, amplitude: 9, phase: 0.4)
        Self.expect(try Self.drawn([.displacement(displacement)])) { Self.read(sheet, displacement.source(of: $0)) }
        let swirl = Picture.Effect.Swirl(center: Tests.at(12, 8), radius: 30, angle: 2.2)
        Self.expect(try Self.drawn([.swirl(swirl)])) { Self.read(sheet, swirl.source(of: $0)) }
        #expect(try Self.drawn([.swirl(.init(center: Tests.at(3, 3), radius: 10, angle: 0))]) == Self.drawn([]))
        #expect(try Self.drawn([.pixelation(.init(width: 0, height: 3))]) == Self.drawn([]))
        #expect(try Self.drawn([.kaleidoscope(.init(center: Tests.at(3, 3), segments: 0))]) == Self.drawn([]))
    }

    @Test
    func `Chromatic takes each channel from its own offset and the largest alpha`() throws {
        let sheet = try Self.sheet()
        let chromatic = Picture.Effect.Chromatic(red: .init([6.5, -1]), green: .init([0, 0.25]), blue: .init([-3, 9]))
        Self.expect(try Self.drawn([.chromatic(chromatic)])) { point in
            chromatic.pixel(
                red: Self.read(sheet, Tests.at(point[0] - 6.5, point[1] + 1)),
                green: Self.read(sheet, Tests.at(point[0], point[1] - 0.25)),
                blue: Self.read(sheet, Tests.at(point[0] + 3, point[1] - 9))
            )
        }
    }

    @Test
    func `Zoom is the mean of the sheet along the stretch toward the centre`() throws {
        let gradient = Picture.Paint.linear(
            .init(from: Tests.at(-200, -100), to: Tests.at(200, 100), .init([.init(offset: 0, color: Tests.red), .init(offset: 1, color: Tests.translucent)]))
        )
        let field: Picture = [.shape(.init(Tests.rectangle(-60, -60, 160, 160), fill: .init(gradient)))]
        let zoom = Picture.Effect.Zoom(center: Tests.at(30, -5), amount: 0.6)
        let drawn = try Tests.drawn([.layer(.init(field, effects: [.zoom(zoom)]))], on: Tests.canvas(Self.width, Self.height))
        Self.expect(drawn, within: 1e-4) { gradient.pixel(at: zoom.source(of: $0, at: 0.5)) }
        let plain = try Tests.drawn([.layer(.init(Self.content))], on: Tests.canvas(Self.width, Self.height))
        #expect(try Self.drawn([.zoom(.init(center: Tests.at(3, 3), amount: 0))]) == plain)
        let still = try Tests.drawn([.layer(.init(Self.content, effects: [.zoom(.init(center: Tests.at(4.5, 2.5), amount: 1))]))], on: Tests.canvas(Self.width, Self.height))
        #expect(Tests.at(still, 4, 2) == Tests.at(plain, 4, 2))
    }

    @Test
    func `Effects apply in order, each to the result of the one before`() throws {
        let blur = Picture.Effect.blur(.init(deviation: 1.5))
        let pixelation = Picture.Effect.pixelation(.init(width: 4, height: 4))
        let nested = try Tests.drawn([.layer(.init([.layer(.init(Self.content, effects: [blur]))], effects: [pixelation]))], on: Tests.canvas(Self.width, Self.height))
        #expect(Tests.close(try Self.drawn([blur, pixelation]), nested))
        #expect(!Tests.close(try Self.drawn([pixelation, blur]), nested))
    }

    @Test
    func `Effects are in the layer's own units, and a larger raster shows the same pixels`() throws {
        let scale = Picture.Transform(rows: [[2, 0, 3], [0, 2, -1]])
        let inside = try Tests.drawn([.group(.init([.layer(.init(Self.content, effects: [.blur(.init(deviation: 1))]))], transform: scale))], on: Tests.canvas(Self.width, Self.height))
        let outside = try Tests.drawn([.layer(.init([.group(.init(Self.content, transform: scale))], effects: [.blur(.init(deviation: 2))]))], on: Tests.canvas(Self.width, Self.height))
        #expect(Tests.close(inside, outside))
        let effects: [[Picture.Effect]] = [
            [.blur(.init(deviation: 3))],
            [.zoom(.init(center: Tests.at(-20, 30), amount: 0.4))],
            [.kaleidoscope(.init(center: Tests.at(5, 6), segments: 3))],
            [.displacement(.init(seed: .init(1, 2), frequency: 0.2, amplitude: 6))],
            [.chromatic(.init(red: .init([-7, 0]), blue: .init([0, 5])))],
            [.blur(.init(deviation: 1)), .pixelation(.init(origin: Tests.at(-1, -1), width: 5, height: 5))],
        ]
        for list in effects {
            let turn = Picture.Transform(rows: [[0.8, -0.6, 2], [0.6, 0.8, 1]])
            let picture: Picture = [.group(.init([.layer(.init(Self.content, effects: list))], transform: turn))]
            let small = try Tests.drawn(picture, on: Tests.canvas(Self.width, Self.height))
            let large = try Tests.drawn(picture, on: Tests.canvas(Self.width + 30, Self.height + 30))
            #expect(Tests.close(small, try large.cropped(to: .init(x: .zero, y: .zero, width: .init(Self.width), height: .init(Self.height)))))
        }
    }

    @Test
    func `A blur under a shear is refused`() {
        var raster = Tests.canvas(4, 4)
        let shear = Picture.Transform(rows: [[1, 0.5, 0], [0, 1, 0]])
        #expect(throws: Picture.Renderer.Error.unsupported) {
            try Tests.renderer.render([.group(.init([.layer(.init(Self.content, effects: [.blur(.init(deviation: 1))]))], transform: shear))], into: &raster)
        }
        #expect(raster == Tests.canvas(4, 4))
    }

    @Test
    func `A glow adds the blurred picture's light, and a backdrop pane replaces what is inside its clip by itself changed`() throws {
        let blurred = try Self.smoothed(try Self.sheet(), 2)
        let plain = try Tests.drawn(Self.content, on: Tests.canvas(Self.width, Self.height))
        let glow = try Tests.drawn(Self.content.glow(deviation: 2, strength: 0.5), on: Tests.canvas(Self.width, Self.height))
        Self.expect(glow) { point in
            let x = UInt(point[0])
            let y = UInt(point[1])
            return Self.read(blurred, point).composited(over: Tests.at(plain, x, y), operator: .lighter, coverage: 0.5)
        }
        let pane = Picture.Clip(Tests.rectangle(4, 2, 10, 8))
        let backdrop = try Tests.drawn(Self.content.backdrop([.blur(.init(deviation: 2))], clip: pane), on: Tests.canvas(Self.width, Self.height))
        Self.expect(backdrop) { point in
            let inside = point[0] > 4 && point[0] < 14 && point[1] > 2 && point[1] < 10
            return inside ? Self.read(blurred, point) : Tests.at(plain, UInt(point[0]), UInt(point[1]))
        }
    }
}
