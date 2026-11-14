import Direction
import Matrix
public import Threefry
import Vector

extension Picture.Text {
    /// One glyph of a text: which, where, and its outline.
    public struct Glyph: Sendable, Hashable {
        /// The code point the glyph stands for.
        public let scalar: Unicode.Scalar

        /// The glyph's number in the font.
        public let index: UInt16

        /// The glyph's own origin: where the pen stood on the baseline.
        public let origin: Picture.Plane.Point<2>

        /// The glyph's own advance width at the text's size, without kerning.
        public let advance: Double

        /// The glyph's outline around its own origin, at the text's size, upright.
        public let outline: Picture.Plane.Path
    }
}

extension Picture.Text.Glyph {
    /// The outline at the glyph's place in the text.
    public var path: Picture.Plane.Path {
        outline.transformed(by: .translation(Vector([origin[0], origin[1]])))
    }
}

extension Picture.Text.Glyph {
    /// The glyph moved by an affine map of the text's plane: its origin goes where the map takes it and its
    /// outline is turned, scaled and sheared by the map's linear part, so that the glyph's `path` is its old
    /// path under the map, up to rounding.
    public func transformed(by map: Picture.Transform) -> Self {
        let place = map.applied(to: Vector([origin[0], origin[1]]))
        return Self(
            scalar: scalar,
            index: index,
            origin: Picture.Plane.Point<2>([place[0], place[1]]),
            advance: advance,
            outline: outline.transformed(by: Picture.Transform(linear: map.linear))
        )
    }
}

extension Picture.Text.Glyph {
    /// The glyph sampled to points: of a lattice of square cells `spacing` wide over the text's plane, one
    /// corner of one cell at the text's origin, the point of every cell whose point lies inside the glyph's
    /// path. A cell's point is its centre, or with a seed a place in the cell that the seed and the cell's
    /// column and row decide. The points come row by row from the top, each row from the left.
    public func points(spacing: Double, seed: Threefry.Key? = nil) -> [Picture.Plane.Point<2>] {
        guard spacing > 0, spacing.isFinite else { return [] }
        let path = path
        guard let box = path.boundingBox else { return [] }
        let low = (column: (box.llx.underlying / spacing).rounded(.down), row: (box.lly.underlying / spacing).rounded(.down))
        let high = (column: (box.urx.underlying / spacing).rounded(.down), row: (box.ury.underlying / spacing).rounded(.down))
        guard abs(low.column) < 0x1p31, abs(low.row) < 0x1p31, abs(high.column) < 0x1p31, abs(high.row) < 0x1p31 else { return [] }
        guard low.column <= high.column, low.row <= high.row else { return [] }
        var points: [Picture.Plane.Point<2>] = []
        var row = Int(low.row)
        while row <= Int(high.row) {
            var column = Int(low.column)
            while column <= Int(high.column) {
                var place = (across: 0.5, down: 0.5)
                if let seed {
                    let cell = Threefry.Block(UInt64(bitPattern: Int64(column)), UInt64(bitPattern: Int64(row)))
                    let drawn = Threefry.block(key: seed, counter: cell)
                    let units = drawn.units(as: Double.self)
                    place = (units.first, units.second)
                }
                let point = Picture.Plane.Point<2>([(Double(column) + place.across) * spacing, (Double(row) + place.down) * spacing])
                if path.contains(point, rule: Winding.Rule.nonzero) { points.append(point) }
                column += 1
            }
            row += 1
        }
        return points
    }
}
