public import Angle
import Numeric
public import Raster

extension Picture.Effect {
    /// `segments` equal sectors around `center`, the first starting at the direction `rotation`.
    /// Each sector is two mirror-image wedges, and every wedge shows the first. Optionally every other wedge
    /// is covered by `spokes`, and a `seam` is drawn along every mirror edge.
    public struct Kaleidoscope: Sendable, Hashable {
        public var center: Picture.Plane.Point<2>
        public var segments: Cardinal
        public var rotation: Radian<Double>
        public var seam: Seam?
        public var spokes: Picture.Color?

        public init(
            center: Picture.Plane.Point<2>,
            segments: Cardinal,
            rotation: Radian<Double> = .zero,
            seam: Seam? = nil,
            spokes: Picture.Color? = nil
        ) {
            self.center = center
            self.segments = segments
            self.rotation = rotation
            self.seam = seam
            self.spokes = spokes
        }
    }
}

extension Picture.Effect.Kaleidoscope {
    /// The point of the sheet read for `point`: its mirror image in the first wedge.
    public func source(of point: Picture.Plane.Point<2>) -> Picture.Plane.Point<2> {
        guard let place = place(of: point) else { return point }
        let folded = place.within > place.sector / 2 ? place.sector - place.within : place.within
        let angle = folded + rotation.underlying
        return Picture.Plane.Point<2>([center[0] + place.radius * Double.cos(angle), center[1] + place.radius * Double.sin(angle)])
    }

    /// The wedge that holds a point, counted from the first in the direction of growing angle, from 0 to
    /// 2 × `segments` − 1: the even ones show the first wedge turned, the odd ones its mirror image. A wedge
    /// holds its edge at the smaller angle. It is nil with no segments and at the centre.
    public func wedge(of point: Picture.Plane.Point<2>) -> Ordinal? {
        guard let place = place(of: point) else { return nil }
        let sector = (place.turned / place.sector).rounded(.down)
        let count = Double(Int(clamping: segments))
        let whole = sector - (sector / count).rounded(.down) * count
        let wedge = 2 * whole + (place.within >= place.sector / 2 ? 1 : 0)
        guard wedge >= 0, wedge.isFinite else { return nil }
        return Ordinal(UInt(wedge))
    }

    /// Whether the first wedge holds a point: its angle from `rotation` is at most half a sector, the edges and
    /// the centre included. With no segments every point is held.
    public func holds(_ point: Picture.Plane.Point<2>) -> Bool {
        guard let place = place(of: point) else { return true }
        return place.within <= place.sector / 2
    }

    /// How far a point lies from the nearest mirror edge, the half-lines from the centre at the directions
    /// `rotation` plus whole multiples of half a sector: the distance to the nearest point of those half-lines.
    /// It is the distance to the centre at the centre, and infinite with no segments.
    public func distance(of point: Picture.Plane.Point<2>) -> Double {
        guard segments > .zero else { return .infinity }
        guard let place = place(of: point) else {
            let across = point[0] - center[0]
            let down = point[1] - center[1]
            return (across * across + down * down).squareRoot()
        }
        let half = place.sector / 2
        let folded = place.within > half ? place.sector - place.within : place.within
        let angle = Swift.min(folded, half - folded)
        return angle < Double.pi / 2 ? place.radius * Double.sin(angle) : place.radius
    }

    /// The share of a square of side `footprint` around a point, taken across the nearest mirror edge, that the
    /// odd wedges cover: the overlap of the stretch of that width around the point's signed distance into them
    /// with the side they lie on, over the width, so from 0 to 1, 1/2 on an edge. A footprint that is not
    /// positive gives 1 or 0 by which wedge holds the point. It is 0 with no segments.
    public func spoke(at point: Picture.Plane.Point<2>, footprint: Double) -> Double {
        guard segments > .zero else { return 0 }
        let inside = place(of: point).map { $0.within >= $0.sector / 2 } ?? false
        let signed = inside ? distance(of: point) : -distance(of: point)
        guard footprint > 0 else { return inside ? 1 : 0 }
        return Swift.min(Swift.max(signed / footprint + 0.5, 0), 1)
    }

    /// The share of a square of side `footprint` around a point, taken across the nearest mirror edge, that the
    /// seam covers: the overlap of the stretch of that width around the point's distance from the edge with the
    /// seam's own width around the edge, over the footprint, so a seam thinner than the footprint is fainter
    /// rather than wider. A footprint that is not positive gives 1 within half the width and 0 beyond. It is
    /// 0 with no seam and no segments.
    public func seam(at point: Picture.Plane.Point<2>, footprint: Double) -> Double {
        guard let seam, seam.width > 0, segments > .zero else { return 0 }
        let distance = distance(of: point)
        let half = seam.width / 2
        guard footprint > 0 else { return distance <= half ? 1 : 0 }
        let overlap = Swift.min(distance + footprint / 2, half) - Swift.max(distance - footprint / 2, -half)
        return Swift.min(Swift.max(overlap / footprint, 0), 1)
    }

    /// The pixel at a point, given the pixel read for it at `source(of:)` and the side of the square a pixel
    /// covers there: the read pixel interpolated to the spokes' pixel by `spoke(at:footprint:)`, and over that
    /// the seam's pixel faded by `seam(at:footprint:)`. Without spokes and seam it is the read pixel.
    public func pixel(_ read: Picture.Pixel, at point: Picture.Plane.Point<2>, footprint: Double) -> Picture.Pixel {
        pixel(read, at: point, footprint: footprint, spokes: spokes?.pixel, seam: seam?.color.pixel)
    }

    /// `pixel(_:at:footprint:)` with the spokes' and the seam's colours taken into working pixels once, as a
    /// renderer makes them once for a layer; it is the same bit for bit.
    public func pixel(
        _ read: Picture.Pixel,
        at point: Picture.Plane.Point<2>,
        footprint: Double,
        spokes: Picture.Pixel?,
        seam: Picture.Pixel?
    ) -> Picture.Pixel {
        var pixel = read
        if let spokes {
            let share = spoke(at: point, footprint: footprint)
            if share > 0 { pixel = pixel.interpolated(to: spokes, at: Float(share)) }
        }
        if let seam {
            let share = self.seam(at: point, footprint: footprint)
            if share > 0 { pixel = Picture.Pixel.transparent.interpolated(to: seam, at: Float(share)).composited(over: pixel) }
        }
        return pixel
    }

    /// Where a point lies around the centre: its distance, its angle from `rotation`, that angle within its
    /// sector, from 0 up to a sector, and the sector's angle. Nil with no segments and at the centre.
    func place(of point: Picture.Plane.Point<2>) -> (radius: Double, turned: Double, within: Double, sector: Double)? {
        let count = Int(clamping: segments)
        guard count > 0 else { return nil }
        let across = point[0] - center[0]
        let down = point[1] - center[1]
        let radius = (across * across + down * down).squareRoot()
        guard radius > 0, radius.isFinite else { return nil }
        let sector = 2 * Double.pi / Double(count)
        let turned = Double.atan2(down, across) - rotation.underlying
        let within = turned - (turned / sector).rounded(.down) * sector
        return (radius, turned, within, sector)
    }
}
