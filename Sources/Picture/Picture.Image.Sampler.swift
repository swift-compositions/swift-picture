public import Matrix
import Point
import Vector

extension Picture.Image {
    /// An image made ready to be read many times: its placement inverted once. `pixel(at:)` is the image's own,
    /// bit for bit.
    public struct Sampler: Sendable {
        public let image: Picture.Image

        /// The placement's inverse, nil for a placement that cannot be inverted.
        public let inverse: Matrix<3, 3, Double>?

        /// The inverse of an affine placement, taken as an affine map, so that such an image reads exactly as
        /// an affine map reads it.
        let affine: Picture.Transform?

        public init(_ image: Picture.Image) {
            self.image = image
            let placement = image.placement
            if placement[2, 0] == 0, placement[2, 1] == 0, placement[2, 2] == 1 {
                let map = Picture.Transform(rows: [
                    [placement[0, 0], placement[0, 1], placement[0, 2]],
                    [placement[1, 0], placement[1, 1], placement[1, 2]],
                ])
                do throws(Matrix<2, 3, Double>.Error) {
                    let inverse = try map.inverted()
                    self.affine = inverse
                    self.inverse = Matrix<3, 3, Double>(inverse)
                } catch {
                    self.affine = nil
                    self.inverse = nil
                }
                return
            }
            self.affine = nil
            do throws(Matrix<3, 3, Double>.Error) {
                self.inverse = try placement.inverted()
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
        let place = Vector<2, Double>([point[0], point[1]])
        let source = affine?.applied(to: place) ?? inverse.projected(place)
        guard source[0].isFinite, source[1].isFinite else { return .transparent }
        return image.raster.sample(at: Point::Point<2, Double>([source[0], source[1]]), image.sampling, edge: image.edge) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }
}
