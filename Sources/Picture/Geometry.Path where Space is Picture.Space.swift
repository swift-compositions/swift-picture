public import Geometry
public import Typesetting

extension Geometry.Path where Scalar == Double, Space == Picture.Space {
    /// A path of a set text in picture space: y, which points up where a text is set, turned to point down, as
    /// it does on a screen, and x as it is. So a glyph's `path` becomes its place in a picture whose origin is
    /// the left end of the first baseline, and its `outline` stands upright around its own origin.
    public init(_ path: Typesetting.Plane.Path) {
        self = path.transformed(by: Picture.Transform(rows: [[1, 0, 0], [0, -1, 0]]), to: Picture.Space.self)
    }
}
