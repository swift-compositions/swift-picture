import ISO_14496_22_Test_Support
import Numeric
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A set text is drawn as its glyphs' paths, y turned down` {}
}

extension `Picture Tests`.`A set text is drawn as its glyphs' paths, y turned down` {
    typealias Tests = `Picture Tests`
    typealias Corner = (x: Int, y: Int)

    static let box: [Corner] = [(0, 0), (400, 0), (400, 700), (0, 700)]
    static let triangle: [Corner] = [(0, 0), (500, 0), (250, 700)]
    static let wedge: [Corner] = [(0, 700), (250, 0), (500, 700)]
    static let capital: [Corner] = [(0, 0), (600, 0), (600, 700), (0, 700)]
    static let small: [Corner] = [(0, 0), (400, 0), (400, 500), (0, 500)]

    /// Glyph 0 is a box, 1 is "A", 2 is "V", 3 is the space and 4 is "B". "A" and "V" kern both ways.
    static func font() -> ISO_14496_22.FontFile {
        ISO_14496_22.FontFile(
            sketches: [
                .init(advance: 500, contours: [box]), .init(advance: 600, contours: [triangle]),
                .init(advance: 600, contours: [wedge]), .init(advance: 300), .init(advance: 700, contours: [box, triangle]),
            ],
            mapping: [0x41: 1, 0x56: 2, 0x20: 3, 0x42: 4],
            kerning: [(1, 2, -100), (2, 1, -50), (1, 3, 20)]
        )
    }

    /// Glyph 0 is a box, 1 is "A", 2 is "V", 3 the space, 4 "H" (a box 700 high) and 5 "x" (a box 500 high).
    static func typeset(os2: ISO_14496_22.OS2? = nil) -> ISO_14496_22.FontFile {
        ISO_14496_22.FontFile(
            sketches: [
                .init(advance: 500, contours: [box]), .init(advance: 600, contours: [triangle]),
                .init(advance: 600, contours: [wedge]), .init(advance: 300), .init(advance: 700, contours: [capital]),
                .init(advance: 500, contours: [small]),
            ],
            mapping: [0x41: 1, 0x56: 2, 0x20: 3, 0x48: 4, 0x78: 5],
            os2: os2
        )
    }

    static func corners(_ path: Picture.Plane.Path) -> [[[Double]]] {
        path.subpaths.map { subpath in
            [[subpath.startPoint[0], subpath.startPoint[1]]]
                + subpath.segments.compactMap { segment in
                    guard case .line(let line) = segment else { return nil }
                    return [line.end[0], line.end[1]]
                }
        }
    }

    /// The vertical extent of a path under a group's transform.
    static func extent(of element: Picture.Element, _ path: Picture.Plane.Path) -> (top: Double, bottom: Double)? {
        guard case .group(let group) = element, let box = path.transformed(by: group.transform).boundingBox else { return nil }
        return (box.lly.underlying, box.ury.underlying)
    }

    @Test
    func `A set path comes into picture space with y turned down and x as it is`() throws {
        let text = try Typesetting.Text("AV\nA", font: Self.font(), size: 100)
        #expect(Self.corners(Picture.Plane.Path(text.glyphs[0].outline)) == [[[0, 0], [50, 0], [25, -70], [0, 0]]])
        #expect(Self.corners(Picture.Plane.Path(text.glyphs[1].path)) == [[[50, -70], [75, 0], [100, -70], [50, -70]]])
        #expect(Self.corners(Picture.Plane.Path(text.glyphs[2].path)) == [[[0, 110], [50, 110], [25, 40], [0, 110]]])
        #expect(Picture.Plane.Path(text.path).subpaths.map(\.isClosed) == [true, true, true])
        let fill = Picture.Shape.Fill(.solid(.white), rule: .evenodd)
        #expect(text.shape(fill) == Picture.Shape(Picture.Plane.Path(text.path), fill: fill))
    }

    @Test
    func `A placed text stands with its first baseline through the point, from either end or the middle`() throws {
        let text = try Typesetting.Text("AV", font: Self.font(), size: 10)
        let fill = Picture.Shape.Fill(.solid(.white))
        let point = Picture.Plane.Point<2>([100, 50])
        #expect(text.placed(fill, at: point) == .group(Picture.Group([.shape(text.shape(fill))], transform: .translation(x: 100, y: 50))))
        let width = text.measure
        #expect(
            text.placed(fill, at: point, anchor: .center)
                == .group(Picture.Group([.shape(text.shape(fill))], transform: .translation(x: 100 - width / 2, y: 50)))
        )
        #expect(
            text.placed(fill, at: point, anchor: .trailing)
                == .group(Picture.Group([.shape(text.shape(fill))], transform: .translation(x: 100 - width, y: 50)))
        )
    }

    @Test
    func `A placed text's bounds hold its ink and move with it`() throws {
        let text = try Typesetting.Text("AV B\nVA", font: Self.font(), size: 10)
        let point = Picture.Plane.Point<2>([100, 50])
        for anchor: Horizontal.Alignment in [.leading, .center, .trailing] {
            for level: Typesetting.Level in [.baseline, .cap(0.5), .ascent] {
                let bounds = try #require(text.bounds(at: point, anchor: anchor, level: level))
                guard case .group(let group) = text.placed(.init(.solid(.white)), at: point, anchor: anchor, level: level) else {
                    Issue.record("a placed text is a group")
                    continue
                }
                let ink = try #require(Picture.Plane.Path(text.path).transformed(by: group.transform).boundingBox)
                #expect(bounds == ink)
            }
        }
        let plain = try #require(text.bounds(at: Picture.Plane.Point<2>([0, 0])))
        #expect(plain.llx.underlying == 0 && abs(plain.ury.underlying - 11) < 1e-9)
        #expect(try Typesetting.Text("  ", font: Self.font(), size: 10).bounds(at: point) == nil)
    }

    @Test
    func `A line put at half its cap height has its capitals' top and bottom equidistant from the point`() throws {
        let fill = Picture.Shape.Fill(.solid(.white))
        let point = Tests.at(320, 180)
        for os2 in [nil, ISO_14496_22.OS2(version: 4, sxHeight: 500, sCapHeight: 700)] {
            let text = try Typesetting.Text("HxH", font: Self.typeset(os2: os2), size: 48)
            let capital = Picture.Plane.Path(text.glyphs[0].path)
            let placed = text.placed(fill, at: point, level: .cap(0.5))
            let extent = try #require(Self.extent(of: placed, capital))
            #expect(Tests.close(point[1] - extent.top, extent.bottom - point[1]))
            #expect(Tests.close(extent.bottom - extent.top, 0.7 * 48))
            let small = try #require(Self.extent(of: text.placed(fill, at: point, level: .ex(0.5)), Picture.Plane.Path(text.glyphs[1].path)))
            #expect(Tests.close(point[1] - small.top, small.bottom - point[1]))
            let top = try #require(Self.extent(of: text.placed(fill, at: point, level: .cap(1)), capital))
            #expect(Tests.close(top.top, point[1]))
            let base = try #require(Self.extent(of: text.placed(fill, at: point), capital))
            #expect(Tests.close(base.bottom, point[1]))
            #expect(text.centered(fill, at: point) == placed)
        }
    }

    @Test
    func `A block of lines is centred between the first line's capitals and the last baseline`() throws {
        let fill = Picture.Shape.Fill(.solid(.white))
        let text = try Typesetting.Text("H\nAx\nH", font: Self.typeset(), size: 100, leading: 90)
        let point = Tests.at(0, 200)
        let block = text.centered(fill, at: point)
        let first = try #require(Self.extent(of: block, Picture.Plane.Path(text.glyphs[0].path)))
        let final = try #require(text.glyphs.last)
        let last = try #require(Self.extent(of: block, Picture.Plane.Path(final.path)))
        #expect(Tests.close(point[1] - first.top, last.bottom - point[1]))
        #expect(Tests.close(last.bottom - first.top, 70 + 180))
        let lowercase = text.centered(fill, at: point, top: .ex(1))
        let small = try #require(Self.extent(of: lowercase, Picture.Plane.Path(text.glyphs[2].path)))
        let end = try #require(Self.extent(of: lowercase, Picture.Plane.Path(final.path)))
        #expect(Tests.close((small.top - 90) + end.bottom, 2 * point[1]))
    }

    @Test
    func `Glyphs wrapped round a band stand on its circle, upright, facing out`() throws {
        let text = try Typesetting.Text("HH", font: Self.typeset(), size: 10)
        let models = text.wrapped(radius: 20, start: Radian(0.3), level: .cap(0.5))
        #expect(models.count == 2)
        for (model, glyph) in zip(models, text.glyphs) {
            let middle = model.applied(to: Vector([glyph.advance / 2, 0, 0, 1]))
            #expect(Tests.close((middle[0] * middle[0] + middle[2] * middle[2]).squareRoot(), 20))
            #expect(Tests.close(middle[1], -3.5))
            let angle = 0.3 + (glyph.origin[0] + glyph.advance / 2) / 20
            #expect(Tests.close(Double.atan2(middle[0], middle[2]), angle))
            let along = model.applied(to: Vector([1, 0, 0, 0]))
            #expect(Tests.close(along[0], Double.cos(angle)) && Tests.close(along[1], 0) && Tests.close(along[2], -Double.sin(angle)))
            let down = model.applied(to: Vector([0, 1, 0, 0]))
            #expect(down[0] == 0 && down[1] == -1 && down[2] == 0)
        }
        #expect(text.wrapped(radius: .nan).isEmpty)
    }

    @Test
    func `A flat path in a model is drawn through the scene's camera, vertex by vertex`() throws {
        let camera = try Picture.Scene.Camera(fieldOfView: Radian(0.8), aspect: 1, near: 1, far: 100, depth: .unit)
        let viewport = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 400, ury: 400)
        let model = Matrix<4, 4, Double>.translation(Vector([0, 0, -10])).multiplied(by: .rotation(aboutY: 0.7))
        let scene = Picture.Scene(camera: camera, viewport: viewport, models: [])
        let square = try #require(Picture.Plane.Path.polygon(vertices: [Tests.at(-1, -1), Tests.at(2, -1), Tests.at(2, 1), Tests.at(-1, 1)]))
        let projection = try scene.projected(square, in: model, tolerance: 0.01)
        let projected = try #require(projection)
        let map = camera.map(of: model)
        let expected = Self.corners(square)[0].map { scene.position(of: Point([$0[0], $0[1], 0]), through: map)?.point }
        let corners = Self.corners(projected)[0].map { Tests.at($0[0], $0[1]) }
        #expect(corners.count == expected.count)
        #expect(zip(corners, expected).allSatisfy { corner, point in point.map { Tests.close(corner, $0, within: 1e-9) } ?? false })
        #expect(projected.subpaths[0].isClosed)
        let behind = Matrix<4, 4, Double>.translation(Vector([0, 0, 10]))
        #expect(try scene.projected(square, in: behind, tolerance: 0.01) == nil)
    }
}
