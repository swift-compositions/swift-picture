import Numeric

extension Picture {
    /// A flat eye on a picture: the point of the picture, `focus`, seen at a point of the frame, `center`, and
    /// how many times larger than drawn the picture is seen, `scale`. A point p of the picture is seen at
    /// `center + scale × (p − focus)`.
    public struct Camera: Sendable, Hashable {
        public var focus: Picture.Plane.Point<2>
        public var center: Picture.Plane.Point<2>
        public var scale: Double

        public init(focus: Picture.Plane.Point<2>, center: Picture.Plane.Point<2>, scale: Double = 1) {
            self.focus = focus
            self.center = center
            self.scale = scale
        }
    }
}

extension Picture.Camera {
    /// The camera that shows a picture as drawn, with the frame's point `center` as its focus.
    public init(center: Picture.Plane.Point<2>) {
        self.init(focus: center, center: center)
    }

    /// Where the camera puts a point of the picture: `center + scale × (point − focus)`, as a transform.
    public var transform: Picture.Transform {
        Picture.Transform(rows: [
            [scale, 0, center[0] - scale * focus[0]],
            [0, scale, center[1] - scale * focus[1]],
        ])
    }

    /// Where on the frame a point of the picture is seen.
    public func place(of point: Picture.Plane.Point<2>) -> Picture.Plane.Point<2> {
        Picture.Plane.Point<2>([center[0] + scale * (point[0] - focus[0]), center[1] + scale * (point[1] - focus[1])])
    }

    /// A picture as this camera sees it: a group under `transform`.
    public func callAsFunction(_ picture: Picture) -> Picture.Element {
        .group(Picture.Group(picture, transform: transform))
    }

    /// A picture as this camera sees it, smeared along the way it came since an earlier camera saw it, as an
    /// open shutter would: drawn as the earlier camera saw it, in a layer under `smear(since:)`. Where the
    /// scale did not change, it is the picture as this camera sees it.
    public func callAsFunction(_ picture: Picture, since earlier: Self) -> Picture.Element {
        guard let smear = smear(since: earlier) else { return self(picture) }
        return .layer(Picture.Layer([earlier(picture)], effects: [.zoom(smear)]))
    }

    /// A picture as this camera sees it through a shutter that was open for the last `shutter` of the way
    /// from an earlier camera: the picture `since:` the camera `earlier.mixed(to: self, at: 1 − shutter)`,
    /// where the shutter opened. A shutter of 1 is open all the way, and one of 0 or less is the plain view.
    public func callAsFunction(_ picture: Picture, since earlier: Self, shutter: Double) -> Picture.Element {
        guard shutter > 0 else { return self(picture) }
        return self(picture, since: earlier.mixed(to: self, at: 1 - shutter))
    }

    /// The camera scaled by a factor about a point of the picture, which it still sees at the same place on the
    /// frame: its scale times the factor, its focus moved toward the point by one over the factor. A factor that
    /// is not positive gives this camera.
    public func scaled(by factor: Double, about point: Picture.Plane.Point<2>) -> Self {
        guard factor > 0 else { return self }
        let focus = Picture.Plane.Point<2>([
            point[0] + (self.focus[0] - point[0]) / factor,
            point[1] + (self.focus[1] - point[1]) / factor,
        ])
        return Self(focus: focus, center: center, scale: scale * factor)
    }

    /// The camera a share of the way to another. With L the logarithm of the ratio of the other scale to this
    /// one, the scale is `scale × exp(share × L)`, by equal ratios, and the focus goes
    /// `expm1(−share × L) / expm1(−L)` of the way, the share itself when L is 0: so between cameras of one
    /// centre the one point of the picture both see at the same place on the frame stays there all the way, a
    /// push toward a point. The centre goes straight. When either scale is not positive it is this camera
    /// below a share of 1 and the other from 1 on.
    public func mixed(to other: Self, at share: Double) -> Self {
        guard scale > 0, other.scale > 0 else { return share < 1 ? self : other }
        let logarithm = Double.log(other.scale / scale)
        let travelled = logarithm == 0 ? share : Double.expm1(-share * logarithm) / Double.expm1(-logarithm)
        return Self(
            focus: Picture.Plane.Point<2>([
                focus[0] + (other.focus[0] - focus[0]) * travelled,
                focus[1] + (other.focus[1] - focus[1]) * travelled,
            ]),
            center: Picture.Plane.Point<2>([
                center[0] + (other.center[0] - center[0]) * share,
                center[1] + (other.center[1] - center[1]) * share,
            ]),
            scale: scale * Double.exp(share * logarithm)
        )
    }

    /// The radial blur that smears a picture seen by this camera along the way it came since an earlier camera
    /// saw it: centred on the one point of the frame that both cameras put the same point of the picture at,
    /// with `1 − 1 / ratio` as amount for the ratio of this scale to the earlier one. It is nil when either
    /// scale is not positive or the two are equal, where no point stands still.
    public func smear(since earlier: Self) -> Picture.Effect.Zoom? {
        guard scale > 0, earlier.scale > 0 else { return nil }
        let ratio = scale / earlier.scale
        guard ratio != 1 else { return nil }
        let now = (x: center[0] - scale * focus[0], y: center[1] - scale * focus[1])
        let then = (x: earlier.center[0] - earlier.scale * earlier.focus[0], y: earlier.center[1] - earlier.scale * earlier.focus[1])
        let still = Picture.Plane.Point<2>([(now.x - ratio * then.x) / (1 - ratio), (now.y - ratio * then.y) / (1 - ratio)])
        return Picture.Effect.Zoom(center: still, amount: 1 - 1 / ratio)
    }
}
