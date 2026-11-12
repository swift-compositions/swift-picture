extension Picture.Shape {
    /// A paint for a pen line along a path, and the pen: its width, join and cap.
    public struct Stroke: Sendable, Hashable {
        public var paint: Picture.Paint
        public var pen: Picture.Plane.Path.Stroke

        public init(_ paint: Picture.Paint, pen: Picture.Plane.Path.Stroke) {
            self.paint = paint
            self.pen = pen
        }
    }
}

extension Picture.Shape.Stroke {
    /// The region the pen covers along a path: its outline, to fill under the nonzero rule.
    public func outline(
        of path: Picture.Plane.Path,
        tolerance: Picture.Plane.Length
    ) throws(Picture.Plane.Path.Error) -> Picture.Plane.Path {
        try path.stroked(pen, tolerance: tolerance)
    }
}
