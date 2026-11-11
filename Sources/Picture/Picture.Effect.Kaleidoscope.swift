public import Angle
import Numeric
public import Raster

extension Picture.Effect {
    /// `segments` equal sectors around `center`, the first starting at the direction `rotation`.
    /// Each sector is two mirror-image wedges, and every wedge shows the first.
    public struct Kaleidoscope: Sendable, Hashable {
        public var center: Picture.Point
        public var segments: Cardinal
        public var rotation: Radian<Double>

        public init(center: Picture.Point, segments: Cardinal, rotation: Radian<Double> = .zero) {
            self.center = center
            self.segments = segments
            self.rotation = rotation
        }
    }
}

extension Picture.Effect.Kaleidoscope {
    /// The point of the sheet read for `point`: its mirror image in the first wedge.
    public func source(of point: Picture.Point) -> Picture.Point {
        let count = Int(clamping: segments)
        guard count > 0 else { return point }
        let across = point[0] - center[0]
        let down = point[1] - center[1]
        let radius = (across * across + down * down).squareRoot()
        guard radius > 0, radius.isFinite else { return point }
        let sector = 2 * Double.pi / Double(count)
        let turned = Double.atan2(down, across) - rotation.underlying
        let within = turned - (turned / sector).rounded(.down) * sector
        let folded = within > sector / 2 ? sector - within : within
        let angle = folded + rotation.underlying
        return Picture.Point([center[0] + radius * Double.cos(angle), center[1] + radius * Double.sin(angle)])
    }
}
