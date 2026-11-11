import Point
public import Raster
import Vector

extension Picture {
    /// A raster of working pixels placed in a shape's space.
    public struct Image: Sendable, Hashable {
        public var raster: Raster<Picture.Pixel>
        public var placement: Picture.Transform
        public var sampling: Raster<Picture.Pixel>.Sampling
        public var edge: Raster<Picture.Pixel>.Edge

        public init(
            _ raster: Raster<Picture.Pixel>,
            placement: Picture.Transform = .identity,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            self.raster = raster
            self.placement = placement
            self.sampling = sampling
            self.edge = edge
        }
    }
}

extension Picture.Image {
    /// The image's pixel at a point of the shape's space.
    public func pixel(at point: Picture.Point) -> Picture.Pixel {
        let inverse: Picture.Transform
        do { inverse = try placement.inverted() } catch { return .transparent }
        if raster.isEmpty {
            guard case .constant(let pixel) = edge else { return .transparent }
            return pixel
        }
        let source = inverse.applied(to: Vector([point[0], point[1]]))
        guard source[0].isFinite, source[1].isFinite else { return .transparent }
        return raster.sample(at: Point::Point<2, Double>([source[0], source[1]]), sampling, edge: edge) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }
}
