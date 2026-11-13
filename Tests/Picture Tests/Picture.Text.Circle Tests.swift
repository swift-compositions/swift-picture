import Numeric
import Picture
import Testing

extension `Picture Tests`.`A text is glyph outlines at places` {
    /// The glyph's frame, read from its box outline: the middle of its advance on its baseline, the way its
    /// baseline runs at unit length, and the corner at the top of its left side.
    static func frame(of glyph: Picture.Text.Glyph, width: Double) -> (middle: [Double], way: [Double], top: [Double]) {
        let corners = corners(glyph.path)[0]
        let way = [(corners[1][0] - corners[0][0]) / width, (corners[1][1] - corners[0][1]) / width]
        let middle = [glyph.origin[0] + way[0] * glyph.advance / 2, glyph.origin[1] + way[1] * glyph.advance / 2]
        return (middle, way, corners[3])
    }

    @Test
    func `A glyph moved by a map has its old path under the map`() throws {
        let text = try Picture.Text("AH", font: Self.typeset(), size: 20)
        let map = Picture.Transform(rows: [[0.6, -0.8, 12], [0.8, 0.6, -3]])
        for glyph in text.glyphs {
            let moved = glyph.transformed(by: map)
            let expected = Self.corners(glyph.path.transformed(by: map))
            let corners = Self.corners(moved.path)
            #expect(zip(expected.joined(), corners.joined()).allSatisfy { Tests.close(Tests.at($0[0], $0[1]), Tests.at($1[0], $1[1]), within: 1e-12) })
            #expect(moved.advance == glyph.advance && moved.index == glyph.index)
        }
    }

    @Test
    func `Glyphs on a circle sit at the radius, turned to the tangent, and cover their arc`() throws {
        let text = try Picture.Text("HHHH", font: Self.typeset(), size: 10, tracking: 0.1)
        let center = Tests.at(100, 100)
        let start = -Double.pi / 2
        let circled = text.circled(center: center, radius: 50, start: Radian(start))
        #expect(circled.count == 4)
        var angles: [Double] = []
        for (glyph, original) in zip(circled, text.glyphs) {
            let frame = Self.frame(of: glyph, width: 6)
            let out = [frame.middle[0] - center[0], frame.middle[1] - center[1]]
            #expect(Tests.close((out[0] * out[0] + out[1] * out[1]).squareRoot(), 50))
            #expect(Tests.close(out[0] * frame.way[0] + out[1] * frame.way[1], 0))
            #expect(Tests.close(frame.way[0] * frame.way[0] + frame.way[1] * frame.way[1], 1))
            let angle = Double.atan2(out[1], out[0])
            #expect(Tests.close(angle, start + (original.origin[0] + original.advance / 2) / 50))
            let top = [frame.top[0] - center[0], frame.top[1] - center[1]]
            #expect((top[0] * top[0] + top[1] * top[1]).squareRoot() > 50)
            angles.append(angle)
        }
        #expect(Tests.close(angles[3] - angles[0], 3 * 8 / 50))
        let top = try #require(circled.first)
        #expect(Self.frame(of: top, width: 6).way[0] > 0.99)
    }

    @Test
    func `Inside a circle the glyphs run the other way with their tops toward the centre`() throws {
        let text = try Picture.Text("HH", font: Self.typeset(), size: 10)
        let center = Tests.at(0, 0)
        let circled = text.circled(center: center, radius: 40, start: Radian(Double.pi / 2), side: .inside, anchor: .center, level: .cap(0.5))
        let frames = circled.map { Self.frame(of: $0, width: 6) }
        #expect(Tests.close(Double.atan2(frames[0].middle[1], frames[0].middle[0]), Double.pi / 2 + 3.5 / 40))
        #expect(Tests.close(Double.atan2(frames[1].middle[1], frames[1].middle[0]), Double.pi / 2 - 3.5 / 40))
        #expect(frames.allSatisfy { $0.way[0] > 0.99 })
        let reach = frames.map { ($0.middle[0] * $0.middle[0] + $0.middle[1] * $0.middle[1]).squareRoot() }
        #expect(reach.allSatisfy { Tests.close($0, 40 + 3.5) })
        #expect(frames.allSatisfy { ($0.top[0] * $0.top[0] + $0.top[1] * $0.top[1]).squareRoot() < 40 })
        #expect(text.circled(center: center, radius: 0, start: .zero).isEmpty)
    }

    @Test
    func `Along a straight path the glyphs only move, and along a circle they follow it`() throws {
        let text = try Picture.Text("HxH", font: Self.typeset(), size: 10)
        let line = try #require(Picture.Plane.Path.polyline(vertices: [Tests.at(20, 50), Tests.at(60, 50), Tests.at(400, 50)]))
        let along = try text.along(line, tolerance: 0.01)
        for (glyph, original) in zip(along, text.glyphs) {
            let expected = Self.corners(original.path.transformed(by: .translation(x: 20, y: 50)))
            #expect(zip(expected.joined(), Self.corners(glyph.path).joined()).allSatisfy { Tests.close(Tests.at($0[0], $0[1]), Tests.at($1[0], $1[1])) })
        }
        let before = try text.along(line, tolerance: 0.01, anchor: .right)
        #expect(Tests.close(before[2].origin[0] + before[2].advance, 20))
        let circle = Picture.Plane.Path(Picture.Plane.Circle(center: Tests.at(0, 0), radius: 30))
        let round = try text.along(circle, tolerance: 0.000001)
        let exact = text.circled(center: Tests.at(0, 0), radius: 30, start: .zero)
        for (glyph, expected) in zip(round, exact) {
            let corners = Self.corners(glyph.path).joined()
            #expect(zip(Self.corners(expected.path).joined(), corners).allSatisfy { Tests.close(Tests.at($0[0], $0[1]), Tests.at($1[0], $1[1]), within: 0.01) })
        }
        #expect(try text.along(Picture.Plane.Path(subpaths: []), tolerance: 0.1).isEmpty)
    }

    @Test
    func `Glyphs wrapped round a band stand on its circle, upright, facing out`() throws {
        let text = try Picture.Text("HH", font: Self.typeset(), size: 10)
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
