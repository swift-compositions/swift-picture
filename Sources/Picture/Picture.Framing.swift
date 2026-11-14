import Numeric

extension Picture {
    /// What part of a picture the frame shows and how large: the point of the picture, `focus`, put at a point
    /// of the frame, `center`, and how many times larger than drawn the picture is shown, `scale`. A point p of
    /// the picture is shown at `center + scale × (p − focus)`, a similarity of the plane that pans and zooms;
    /// an eye that looks into a scene is a `Picture.Scene.Camera`.
    public struct Framing: Sendable, Hashable {
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

extension Picture.Framing {
    /// The framing that shows a picture as drawn, with the frame's point `center` as its focus.
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

    /// A picture as this framing shows it: a group under `transform`.
    public func callAsFunction(_ picture: Picture) -> Picture.Element {
        .group(Picture.Group(picture, transform: transform))
    }

    /// A picture as this framing shows it through a shutter that was open for the last `shutter` of the way from
    /// an earlier framing, blurred by the framing's travel as the exposure says. The shutter opened at
    /// `earlier.interpolated(to: self, at: 1 − shutter)`. `samples(n)` is `Picture.exposure(samples:_:)` of the
    /// picture under the framing interpolated from the opening to this one at each fraction: exact for every
    /// travel, at n times the picture. `bands(n)` is the picture shown as at the opening in a layer under
    /// `smear(since:)` of the opening: a framing's picture is flat, so it is one band whatever n, and the zoom is
    /// exact for a change of scale and leaves no smear for a framing that only moves sideways. A shutter that is
    /// not positive, a framing that did not move, no samples, no bands and a travel the zoom cannot show give
    /// the picture as this framing shows it.
    public func exposure(_ picture: Picture, since earlier: Self, shutter: Double = 1, _ exposure: Picture.Exposure) -> Picture {
        guard shutter > 0 else { return [self(picture)] }
        let opened = earlier.interpolated(to: self, at: 1 - shutter)
        guard opened != self else { return [self(picture)] }
        switch exposure {
        case .samples(let samples):
            guard samples > .zero else { return [self(picture)] }
            return Picture.exposure(samples: samples) { fraction in
                [opened.interpolated(to: self, at: fraction)(picture)]
            }

        case .bands(let bands):
            guard bands > .zero, let smear = smear(since: opened) else { return [self(picture)] }
            return [.layer(Picture.Layer([opened(picture)], effects: [.zoom(smear)]))]
        }
    }

    /// The framing scaled by a factor about a point of the picture, which it still sees at the same place on the
    /// frame: its scale times the factor, its focus moved toward the point by one over the factor. A factor that
    /// is not positive gives this framing.
    public func scaled(by factor: Double, about point: Picture.Plane.Point<2>) -> Self {
        guard factor > 0 else { return self }
        let focus = Picture.Plane.Point<2>([
            point[0] + (self.focus[0] - point[0]) / factor,
            point[1] + (self.focus[1] - point[1]) / factor,
        ])
        return Self(focus: focus, center: center, scale: scale * factor)
    }

    /// The framing a share of the way to another. With L the logarithm of the ratio of the other scale to this
    /// one, the scale is `scale × exp(share × L)`, by equal ratios, and the focus goes
    /// `expm1(−share × L) / expm1(−L)` of the way, the share itself when L is 0: so between cameras of one
    /// centre the one point of the picture both show at the same place on the frame stays there all the way, a
    /// push toward a point. The centre goes straight. When either scale is not positive it is this framing
    /// below a share of 1 and the other from 1 on.
    public func interpolated(to other: Self, at share: Double) -> Self {
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

    /// The radial blur that smears a picture shown by this framing along the way it came since an earlier framing
    /// showed it: centred on the one point of the frame that both framings put the same point of the picture at,
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
