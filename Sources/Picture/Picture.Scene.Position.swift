public import Point
public import Projection

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
    /// The position of normalised coordinates in a viewport: `Projection.Viewport.point(_:)` of swift-projection
    /// for a viewport whose y grows downward, as a raster's rows do, so x goes from −1…1 onto the viewport's x
    /// range and y from 1…−1 onto its y range, and the normalised z as depth. A viewport with no area or not
    /// finite puts every point at its first corner.
    @inlinable
    public init(_ normalized: Point::Point<3, Double>, in viewport: Picture.Plane.Rectangle) {
        guard let viewport = Picture.Scene.viewport(of: viewport) else {
            self.init(point: Picture.Plane.Point<2>([viewport.llx.underlying, viewport.lly.underlying]), depth: normalized[2])
            return
        }
        let point = viewport.point(Point::Point<2, Double>(x: normalized[0], y: normalized[1]))
        self.init(point: Picture.Plane.Point<2>([point.x, point.y]), depth: normalized[2])
    }
}

extension Picture.Scene {
    /// A rectangle of the picture as swift-projection's viewport, its y growing downward: x from `llx`, y from
    /// `lly`, nil for one with no area or not finite.
    @usableFromInline
    package static func viewport(of rectangle: Picture.Plane.Rectangle) -> Projection<Double>.Viewport? {
        let (x, y) = (rectangle.llx.underlying, rectangle.lly.underlying)
        do throws(Projection<Double>.Error) {
            return try Projection<Double>.Viewport(
                x: x,
                y: y,
                width: rectangle.urx.underlying - x,
                height: rectangle.ury.underlying - y,
                direction: .down
            )
        } catch {
            return nil
        }
    }
}
