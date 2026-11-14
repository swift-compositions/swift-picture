public import Geometry
public import Matrix
public import Point

extension Picture {
    /// Meshes seen through a camera and drawn into a rectangle of the picture, through an optional haze.
    public struct Scene: Sendable, Hashable {
        public var camera: Camera
        public var viewport: Picture.Plane.Rectangle
        public var models: [Model]
        public var haze: Haze?

        /// What is around the scene, for the bodies of its glass to mirror and to show where light leaves them too
        /// far aside to meet the picture behind, or nothing.
        public var surroundings: Picture.Glass.Surroundings?

        /// The soft shadows the scene's glass casts on the picture around it, from the outline of all its glass as
        /// drawn, in order, after the opaque models and before the glass.
        public var shadows: [Picture.Glass.Shadow]

        public init(
            camera: Camera,
            viewport: Picture.Plane.Rectangle,
            models: [Model],
            haze: Haze? = nil,
            surroundings: Picture.Glass.Surroundings? = nil,
            shadows: [Picture.Glass.Shadow] = []
        ) {
            self.camera = camera
            self.viewport = viewport
            self.models = models
            self.haze = haze
            self.surroundings = surroundings
            self.shadows = shadows
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
        return Position(normalized, in: viewport)
    }

    /// The point of the world the scene shows at a point of the picture, at a distance ahead of the eye:
    /// `Camera.point(under:distance:viewport:)` through this scene's camera and viewport.
    public func point(under point: Picture.Plane.Point<2>, distance: Double) -> Point::Point<3, Double>? {
        camera.point(under: point, distance: distance, viewport: viewport)
    }

    /// The model transform that stands a model's origin at a point of the picture, at a distance ahead of the
    /// eye: `Camera.placement(at:distance:viewport:)` through this scene's camera and viewport.
    public func placement(at point: Picture.Plane.Point<2>, distance: Double) -> Matrix<4, 4, Double>? {
        camera.placement(at: point, distance: distance, viewport: viewport)
    }

    /// Where the scene draws a point of a model, with its distance ahead of the eye: `Camera.sight(of:in:viewport:)`
    /// through this scene's camera and viewport.
    public func sight(of point: Point::Point<3, Double>, in model: Model) -> Camera.Sight? {
        camera.sight(of: point, in: model.transform, viewport: viewport)
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

extension Picture.Scene {
    /// The scene as its camera sees it through a shutter that was open for the last `shutter` of the way
    /// from an earlier camera, blurred by the camera's travel as the exposure says: `exposure(since:shutter:_:)`
    /// of this scene seen by the earlier camera, so the shutter opened at the camera
    /// `earlier.mixed(to: camera, at: 1 − shutter)`. A shutter that is not positive, a camera that did not move,
    /// and an exposure of no samples or no bands give the scene itself.
    public func exposure(since earlier: Camera, shutter: Double = 1, _ exposure: Exposure) -> Picture {
        var then = self
        then.camera = earlier
        return self.exposure(since: then, shutter: shutter, exposure)
    }

    /// The scene through a shutter that was open for the last `shutter` of the way from the same scene a moment
    /// earlier, blurred by how its camera and its models moved as the exposure says. The earlier scene gives the
    /// earlier camera and the earlier transform of each model, paired with this scene's models by their place
    /// in the list; a model past the end of the earlier list stood still. Everything else is this scene's. The
    /// shutter opened at `mixed(since:at:)` of 1 − shutter: the camera as `Camera.mixed(to:at:)` mixes it, and
    /// each model's transform as a rigid motion (`Matrix.Rigid.interpolated(to:at:)`, its origin going straight
    /// and its turn even) where both transforms are one to within a millionth, and entry by entry where either is
    /// not. `samples(n)` is `Picture.exposure(samples:_:)` of the scene mixed from the opening to this one at each
    /// fraction; `bands(n)` draws each band of `bands` as it stood at the opening, in a layer under
    /// `smear(since:)` of the band against the band at the opening. A shutter that is not positive, a scene that
    /// did not move, and an exposure of no samples or no bands give the scene itself.
    public func exposure(since earlier: Picture.Scene, shutter: Double = 1, _ exposure: Exposure) -> Picture {
        guard shutter > 0 else { return [.scene(self)] }
        let opened = mixed(since: earlier, at: 1 - shutter)
        guard opened != self else { return [.scene(self)] }
        switch exposure {
        case .samples(let samples):
            guard samples > .zero else { return [.scene(self)] }
            return Picture.exposure(samples: samples) { fraction in
                [.scene(mixed(since: opened, at: fraction))]
            }

        case .bands(let bands):
            guard bands > .zero else { return [.scene(self)] }
            return Picture(
                self.members(Int(clamping: bands)).map { members in
                    var band = self
                    band.models = members.map { models[$0] }
                    var then = opened
                    then.models = members.map { opened.models[$0] }
                    guard let zoom = band.smear(since: then) else { return .scene(band) }
                    return .layer(Picture.Layer([.scene(then)], effects: [.zoom(zoom)]))
                }
            )
        }
    }

    /// The scene a share of the way from an earlier one: the camera `earlier.camera.mixed(to: camera, at:)`, and
    /// each model's transform from its earlier one, paired by place in the list, as a rigid motion where both are
    /// one to within a millionth and entry by entry otherwise; a model the earlier scene does not list stands
    /// still. A share of 1 gives this scene's camera and transforms.
    func mixed(since earlier: Picture.Scene, at share: Double) -> Self {
        var scene = self
        scene.camera = earlier.camera.mixed(to: camera, at: share)
        for index in models.indices where index < earlier.models.count {
            scene.models[index].transform = Self.mixed(earlier.models[index].transform, models[index].transform, at: share)
        }
        return scene
    }

    /// Two model transforms mixed: equal ones kept, the first at a share of 0 and the second at 1, as rigid
    /// motions where both are one to within a millionth, and entry by entry where either is not.
    static func mixed(_ first: Matrix<4, 4, Double>, _ second: Matrix<4, 4, Double>, at share: Double) -> Matrix<4, 4, Double> {
        if first == second || share == 0 { return first }
        if share == 1 { return second }
        guard let start = Matrix<4, 4, Double>.Rigid(first, within: 1e-6), let end = Matrix<4, 4, Double>.Rigid(second, within: 1e-6) else {
            return Matrix<4, 4, Double>(
                rows: InlineArray { row in
                    InlineArray { column in first[row, column] + (second[row, column] - first[row, column]) * share }
                }
            )
        }
        return start.interpolated(to: end, at: share).matrix
    }

    /// The places in the list of the scene's models in `count` bands by the distance ahead of the eye of each model's mean vertex, cut
    /// evenly in one over that distance between the farthest model and the nearest, so that a forward travel
    /// smears each band about as much more than the one behind it; the bands from far to near, each its models'
    /// places in their order, empty bands left out. A model with no vertices or a mean vertex not ahead of
    /// the eye goes with the nearest.
    func members(_ count: Int) -> [[Int]] {
        let nearness: [Double?] = models.map { model in
            let vertices = model.mesh.vertices
            guard !vertices.isEmpty else { return nil }
            let total = vertices.reduce((x: 0.0, y: 0.0, z: 0.0)) { sum, vertex in (sum.x + vertex[0], sum.y + vertex[1], sum.z + vertex[2]) }
            let size = Double(vertices.count)
            let mean = Point::Point<3, Double>([total.x / size, total.y / size, total.z / size])
            let distance = camera.distance(of: mean, in: model.transform)
            guard distance > 0, distance.isFinite else { return nil }
            return 1 / distance
        }
        let known = nearness.compactMap { $0 }
        let low = known.min() ?? 0
        let high = known.max() ?? 0
        let bands = nearness.map { inverse -> Int in
            guard let inverse else { return count - 1 }
            guard high > low else { return 0 }
            return Swift.min(count - 1, Int(((inverse - low) / (high - low) * Double(count)).rounded(.down)))
        }
        return (0..<count).compactMap { band in
            let members = zip(models.indices, bands).filter { $0.1 == band }.map(\.0)
            return members.isEmpty ? nil : members
        }
    }

    /// The radial blur that best smears the scene along the way its points came on the frame since an earlier
    /// camera saw them: the zoom whose read at fraction 1 is, by least squares over every vertex that both
    /// cameras see, where the earlier camera put the point this one sees there. A zoom reads from a point
    /// toward its centre, so it carries the frame by a scale about a point; a travel that is a shift alone is
    /// taken as a zoom of amount 10⁻⁶ about a centre far along the shift. It is nil when fewer than two vertices
    /// are seen by both or none moves by a millionth of a unit.
    public func smear(since earlier: Camera) -> Picture.Effect.Zoom? {
        var then = self
        then.camera = earlier
        return smear(since: then)
    }

    /// The radial blur that best smears the scene along the way its points came on the frame since the same scene
    /// a moment earlier: `smear(since:)` of a camera, with each vertex seen then through the earlier scene's camera
    /// and the earlier transform of its model, paired by place in the list; a model the earlier scene does not
    /// list stood still.
    public func smear(since earlier: Picture.Scene) -> Picture.Effect.Zoom? {
        var count = 0.0
        var sums = (px: 0.0, py: 0.0, qx: 0.0, qy: 0.0, pp: 0.0, pq: 0.0)
        var pairs: [(now: Picture.Plane.Point<2>, then: Picture.Plane.Point<2>)] = []
        for (index, model) in models.enumerated() {
            let now = camera.map(of: model.transform)
            let then = earlier.camera.map(of: index < earlier.models.count ? earlier.models[index].transform : model.transform)
            for vertex in model.mesh.vertices {
                guard let seen = position(of: vertex, through: now)?.point,
                    let normalized = Camera.normalized(vertex, through: then)
                else { continue }
                let was = Position(normalized, in: viewport).point
                count += 1
                sums.px += seen[0]
                sums.py += seen[1]
                sums.qx += was[0]
                sums.qy += was[1]
                sums.pp += seen[0] * seen[0] + seen[1] * seen[1]
                sums.pq += seen[0] * was[0] + seen[1] * was[1]
                pairs.append((seen, was))
            }
        }
        guard count >= 2 else { return nil }
        let mean = (x: sums.px / count, y: sums.py / count)
        let spread = sums.pp - (sums.px * sums.px + sums.py * sums.py) / count
        let together = sums.pq - (sums.px * sums.qx + sums.py * sums.qy) / count
        let scale = spread > 0 && (together / spread).isFinite ? together / spread : 1
        let shift = (x: sums.qx / count - scale * mean.x, y: sums.qy / count - scale * mean.y)
        let travel = pairs.map { pair in
            let x = scale * pair.now[0] + shift.x - pair.now[0]
            let y = scale * pair.now[1] + shift.y - pair.now[1]
            return (x * x + y * y).squareRoot()
        }
        guard let largest = travel.max(), largest >= 1e-6, largest.isFinite else { return nil }
        let amount = abs(1 - scale) >= 1e-6 ? 1 - scale : 1e-6
        let target = (x: scale * mean.x + shift.x, y: scale * mean.y + shift.y)
        return Picture.Effect.Zoom(
            center: Picture.Plane.Point<2>([mean.x + (target.x - mean.x) / amount, mean.y + (target.y - mean.y) / amount]),
            amount: amount
        )
    }
}
