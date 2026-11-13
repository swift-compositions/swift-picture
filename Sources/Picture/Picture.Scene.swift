public import Geometry
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

extension Picture.Scene {
    /// A flat path lying in a model, as the scene draws it: the path's point (x, y) is the model's point
    /// (x, y, 0), and the path, flattened to within `tolerance` in the model's units, has each vertex put at
    /// its `position(of:in:)`. Straight lines stay straight through a perspective, so this is the path's
    /// picture up to the flattening, magnified as much as the camera magnifies the model there. It is nil
    /// when a vertex lies in the plane of the eye or behind it. Nothing hides it: depth is not kept, and a
    /// caller that draws several such paths orders them from far to near.
    public func projected(
        _ path: Picture.Plane.Path,
        in model: Matrix<4, 4, Double>,
        tolerance: Picture.Plane.Length
    ) throws(Picture.Plane.Path.Error) -> Picture.Plane.Path? {
        let map = camera.map(of: model)
        let flat = try path.flattened(tolerance: tolerance)
        var subpaths: [Picture.Plane.Path.Subpath] = []
        for subpath in flat.subpaths {
            var vertices = [subpath.startPoint]
            for segment in subpath.segments {
                guard case .line(let line) = segment else { continue }
                vertices.append(line.end)
            }
            var points: [Picture.Plane.Point<2>] = []
            for vertex in vertices {
                guard let position = position(of: Point::Point<3, Double>([vertex[0], vertex[1], 0]), through: map) else { return nil }
                points.append(position.point)
            }
            let lines = zip(points, points.dropFirst()).map { from, to in
                Picture.Plane.Path.Segment.line(.init(start: from, end: to))
            }
            guard let start = points.first else { continue }
            subpaths.append(Picture.Plane.Path.Subpath(startPoint: start, segments: lines, isClosed: subpath.isClosed))
        }
        return Picture.Plane.Path(subpaths: subpaths)
    }
}
