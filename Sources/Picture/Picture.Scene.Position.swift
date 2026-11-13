public import Point

extension Picture.Scene {
    /// A point of a scene as it is drawn: where in the picture, and how deep.
    public struct Position: Sendable, Hashable {
        public var point: Picture.Plane.Point<2>
        public var depth: Double

        public init(point: Picture.Plane.Point<2>, depth: Double) {
            self.point = point
            self.depth = depth
        }
    }
}

extension Picture.Scene.Position {
    /// The position of normalised coordinates in a viewport: x from −1…1 onto the viewport's x range, y from
    /// 1…−1 onto its y range, and the normalised z as depth.
    @inlinable
    public init(_ normalized: Point::Point<3, Double>, in viewport: Picture.Plane.Rectangle) {
        let left = viewport.llx.underlying
        let top = viewport.lly.underlying
        let width = viewport.urx.underlying - left
        let height = viewport.ury.underlying - top
        self.init(
            point: Picture.Plane.Point<2>([left + (normalized[0] + 1) / 2 * width, top + (1 - normalized[1]) / 2 * height]),
            depth: normalized[2]
        )
    }
}
