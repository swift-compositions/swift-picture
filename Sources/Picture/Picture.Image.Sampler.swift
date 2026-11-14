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

        /// What `pixel(at:)` reads, taken out of the image once: the raster, the inverse's entries row by row,
        /// whether the image is read at all and whether the map is affine.
        let raster: Raster<Picture.Pixel>
        let entries: InlineArray<9, Double>
        let reads: Bool
        let flat: Bool

        public init(_ image: Picture.Image) {
            self.image = image
            self.raster = image.raster
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
            } else {
                self.affine = nil
                do throws(Matrix<3, 3, Double>.Error) {
                    self.inverse = try placement.inverted()
                } catch {
                    self.inverse = nil
                }
            }
            self.flat = affine != nil
            self.reads = image.source == nil && inverse != nil
            let matrix = inverse ?? .identity
            var entries = InlineArray<9, Double>(repeating: 0)
            for row in 0..<3 {
                for column in 0..<3 {
                    entries[row * 3 + column] = matrix[row, column]
                }
            }
            if let affine {
                for row in 0..<2 {
                    for column in 0..<3 {
                        entries[row * 3 + column] = affine[row, column]
                    }
                }
            }
            self.entries = entries
        }
    }
}

extension Picture.Image {
    /// This image made ready to be read many times.
    public var sampler: Sampler { Sampler(self) }
}

extension Picture.Image.Sampler {
    /// The image's pixel at a point of the shape's space. The point is taken through the inverse as swift-matrix
    /// takes it, `applied(to:)` for an affine map and `projected(_:)` otherwise, each sum from zero in the order of
    /// the columns, bit for bit.
    public func pixel(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        guard reads else { return .transparent }
        if raster.isEmpty {
            guard case .constant(let pixel) = image.edge else { return .transparent }
            return pixel
        }
        let (x, y) = (point[0], point[1])
        let source: (x: Double, y: Double)
        if flat {
            source = (0 + entries[0] * x + entries[1] * y + entries[2], 0 + entries[3] * x + entries[4] * y + entries[5])
        } else {
            let w = 0 + entries[6] * x + entries[7] * y + entries[8] * 1
            source = ((0 + entries[0] * x + entries[1] * y + entries[2] * 1) / w, (0 + entries[3] * x + entries[4] * y + entries[5] * 1) / w)
        }
        guard source.x.isFinite, source.y.isFinite else { return .transparent }
        return raster.sample(at: Point::Point<2, Double>([source.x, source.y]), image.sampling, edge: image.edge) { from, to, parameter in
            from.interpolated(to: to, at: Float(parameter))
        }
    }
}
