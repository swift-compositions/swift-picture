import Point
import Vector

extension Picture.Image {
    /// An image made ready to be read many times: its placement inverted once. `pixel(at:)` is the image's own,
    /// bit for bit.
    public struct Sampler: Sendable {
        public let image: Picture.Image
        public let inverse: Picture.Transform?

        public init(_ image: Picture.Image) {
            self.image = image
            do throws(Matrix<2, 3, Double>.Error) {
                self.inverse = try image.placement.inverted()
            } catch {
                self.inverse = nil
            }
        }
    }
}

extension Picture.Image {
    /// This image made ready to be read many times.
    public var sampler: Sampler { Sampler(self) }
}

extension Picture.Image.Sampler {
    /// The image's pixel at a point of the shape's space.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        guard image.source == nil, let inverse else { return .transparent }
        if image.raster.isEmpty {
            guard case .constant(let pixel) = image.edge else { return .transparent }
            return pixel
        }
        let source = inverse.applied(to: Vector([point[0], point[1]]))
        guard source[0].isFinite, source[1].isFinite else { return .transparent }
        return image.raster.sample(at: Point::Point<2, Double>([source[0], source[1]]), image.sampling, edge: image.edge) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }
}
