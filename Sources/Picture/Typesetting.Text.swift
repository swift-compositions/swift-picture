public import Angle
public import Matrix
import Numeric
public import Typesetting

extension Typesetting.Text {
    /// The whole text as one shape with a fill: its `path` in picture space, the left end of the first
    /// baseline at the origin.
    public func shape(_ fill: Picture.Shape.Fill) -> Picture.Shape {
        Picture.Shape(Picture.Plane.Path(path), fill: fill)
    }

    /// The whole text filled and put at a point: the first line's `level` passes through the point, its
    /// baseline by default, and the point is the left end, the middle or the right end of the measure as
    /// `anchor` says. It is `shape(_:)` in a group moved by the text's `point(at:level:)`, y turned down.
    public func placed(
        _ fill: Picture.Shape.Fill,
        at point: Picture.Plane.Point<2>,
        anchor: Horizontal.Alignment = .leading,
        level: Typesetting.Level = .baseline
    ) -> Picture.Element {
        .group(Picture.Group([.shape(shape(fill))], transform: move(to: point, anchor: anchor, level: level)))
    }

    /// The box of the ink the text puts down where `placed(_:at:anchor:level:)` puts it: the bounding box of
    /// its path under the same move, so it holds every point a fill of the text covers and none of the empty
    /// advance around it. Nil for a text that draws nothing, as one of spaces.
    public func bounds(
        at point: Picture.Plane.Point<2>,
        anchor: Horizontal.Alignment = .leading,
        level: Typesetting.Level = .baseline
    ) -> Picture.Plane.Rectangle? {
        Picture.Plane.Path(path).transformed(by: move(to: point, anchor: anchor, level: level)).boundingBox
    }

    /// The move `placed(_:at:anchor:level:)` makes.
    func move(to point: Picture.Plane.Point<2>, anchor: Horizontal.Alignment, level: Typesetting.Level) -> Picture.Transform {
        let anchored = self.point(at: anchor, level: level)
        return .translation(x: point[0] - anchored[0], y: point[1] + anchored[1])
    }

    /// The whole text filled and centred on a point as a block: the point lies midway between the first
    /// line's `top`, the top of its capitals by default, and the last line's baseline, and is the left end,
    /// the middle or the right end of the measure as `anchor` says. For one line and the default top it is
    /// `placed(_:at:anchor:level:)` at `.cap(0.5)`.
    public func centered(
        _ fill: Picture.Shape.Fill,
        at point: Picture.Plane.Point<2>,
        anchor: Horizontal.Alignment = .leading,
        top: Typesetting.Level = .cap(1)
    ) -> Picture.Element {
        let anchored = self.point(at: anchor)
        let middle = (-(lines.last?.baseline ?? 0) - top.height(in: metrics)) / 2
        let move = Picture.Transform.translation(x: point[0] - anchored[0], y: point[1] - middle)
        return .group(Picture.Group([.shape(shape(fill))], transform: move))
    }

    /// The glyphs wrapped round a band in space: for each glyph, in the order of `glyphs`, the model matrix
    /// that takes its outline in picture space, `Picture.Plane.Path(glyph.outline)`, a flat path around its
    /// own origin with y down, to its place on a circle of `radius` about the y axis, in the plane through the
    /// first line's `level`, standing upright with y up and facing out.
    ///
    /// A glyph's place along the circle is the middle of its advance, its distance along the line from the
    /// left end, the middle or the right end of the measure as `anchor` says, taken as arc length from the
    /// angle `start` about the y axis: at angle 0 the glyph stands at +z, toward an eye looking along −z,
    /// and the text reads to the right there, toward +x. A later line stands lower on the same band. An
    /// outline's point (x, y) is the model's point (x, −y, 0), so `Picture.Scene.projected(_:in:tolerance:)` of
    /// the outline in a model times this matrix draws the glyph through a camera. A radius that is not
    /// positive and finite gives no matrices.
    public func wrapped(
        radius: Double,
        start: Radian<Double> = .zero,
        anchor: Horizontal.Alignment = .leading,
        level: Typesetting.Level = .baseline
    ) -> [Matrix<4, 4, Double>] {
        guard radius > 0, radius.isFinite else { return [] }
        let anchored = point(at: anchor, level: level)
        return glyphs.map { glyph in
            let half = glyph.advance / 2
            let angle = start.underlying + (glyph.origin[0] + half - anchored[0]) / radius
            let (cosine, sine) = (Double.cos(angle), Double.sin(angle))
            let height = glyph.origin[1] - anchored[1]
            return Matrix<4, 4, Double>(rows: [
                [cosine, 0, sine, radius * sine - half * cosine],
                [0, -1, 0, height],
                [-sine, 0, cosine, radius * cosine + half * sine],
                [0, 0, 0, 1],
            ])
        }
    }
}
