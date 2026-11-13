public import Matrix
public import Point

extension Picture {
    /// Meshes seen through a camera and drawn into a rectangle of the picture.
    public struct Scene: Sendable, Hashable {
        public var camera: Camera
        public var viewport: Picture.Plane.Rectangle
        public var models: [Model]

        public init(camera: Camera, viewport: Picture.Plane.Rectangle, models: [Model]) {
            self.camera = camera
            self.viewport = viewport
            self.models = models
        }
    }
}

extension Picture.Scene {
    /// Where the scene draws a point of a model: its place in the picture and its depth.
    /// It is nil for a point in the plane of the eye or behind it.
    public func position(of point: Point::Point<3, Double>, in model: Model) -> Position? {
        position(of: point, through: camera.map(of: model.transform))
    }

    /// Where the scene draws a point after a matrix into clip space, `Camera.map(of:)` of a model's transform,
    /// so that `position(of:in:)` is this with the product made once per model instead of per point.
    @inlinable
    public func position(of point: Point::Point<3, Double>, through map: Matrix<4, 4, Double>) -> Position? {
        guard let normalized = Camera.normalized(point, through: map) else { return nil }
        let left = viewport.llx.underlying
        let top = viewport.lly.underlying
        let width = viewport.urx.underlying - left
        let height = viewport.ury.underlying - top
        return Position(
            point: Picture.Plane.Point<2>([left + (normalized[0] + 1) / 2 * width, top + (1 - normalized[1]) / 2 * height]),
            depth: normalized[2]
        )
    }
}
