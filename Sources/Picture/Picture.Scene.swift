public import Point

extension Picture {
    /// Meshes seen through a camera and drawn into a rectangle of the picture.
    public struct Scene: Sendable, Hashable {
        public var camera: Camera
        public var viewport: Geometry<Double, Picture.Space>.Rectangle
        public var models: [Model]

        public init(camera: Camera, viewport: Geometry<Double, Picture.Space>.Rectangle, models: [Model]) {
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
        guard let normalized = camera.normalized(point, in: model.transform) else { return nil }
        let left = viewport.llx.underlying
        let top = viewport.lly.underlying
        let width = viewport.urx.underlying - left
        let height = viewport.ury.underlying - top
        return Position(
            point: Picture.Point([left + (normalized[0] + 1) / 2 * width, top + (1 - normalized[1]) / 2 * height]),
            depth: normalized[2]
        )
    }
}
