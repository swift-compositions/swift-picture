import Numeric
import Picture

extension Picture.Renderer.CPU {
    /// What light does at one point of glass with a body: the way light of the glass's own index takes in at the
    /// point and out of the far side, from which `read(for:)` finds where light of any index reads the picture
    /// behind; the direction the surface mirrors there, and the share of light it mirrors.
    struct Traversal {
        let place: Vector<3, Double>
        let sight: Vector<3, Double>
        let toward: Vector<3, Double>

        /// The far side's normal where the light leaves, or none where no far side is found.
        let exit: Vector<3, Double>?
        let point: Read
        let own: (x: Double, y: Double)?

        /// How squarely the line of sight meets the surface: the cosine between them.
        let cosine: Double

        /// The depth in eye space of the plane the picture behind stands on.
        let plane: Double

        /// The glass's own index, and the line of sight bent into the body by it.
        let index: Refraction.Index<Double>
        let inner: Vector<3, Double>

        /// Where light of the glass's own index reads the picture.
        var read: Read

        /// How far the light travels inside the body, in the scene's units.
        var length: Double

        /// The direction light of the glass's own index leaves the far side in, and the share of it that misses
        /// the picture behind.
        var leaving: Vector<3, Double>
        var beyond: Double
        var mirrored: Vector<3, Double>
        var share: Double
    }
}

extension Picture.Renderer.CPU.Traversal {
    /// The line of sight is bent into the body at `place`, a point of the near side in eye space with the unit
    /// normal `normal`. Where it leaves is found on the far side as drawn: the path's length starts as the
    /// body's thickness along the line of sight and is corrected three times to end at the far side's depth
    /// where the path's end is drawn. There the light is bent out again by the far side's normal, or mirrored
    /// back in where none can leave, and reads the picture where it meets the plane of the picture behind, at the
    /// depth `plane` in eye space. Light of the glass's own index finds the way; light of any other index, `read(for:lens:)`, follows
    /// a path of the same length under its own. Where no far side is found the light goes straight on, and a
    /// place that cannot be drawn reads at `point`. Places are drawn relative to where `place` itself is drawn,
    /// so that light going straight on reads at `point` exactly.
    init(
        from place: Vector<3, Double>,
        normal: Vector<3, Double>,
        at point: Read,
        through body: Picture.Glass.Body,
        surroundings: Picture.Glass.Surroundings?,
        plane: Double,
        lens: Picture.Renderer.CPU.Lens,
        far: Picture.Renderer.CPU.Far
    ) {
        let sight = lens.sight(through: place)
        let toward = Self.dot(normal, sight) > 0 ? Self.scaled(normal, -1) : normal
        let cosine = -Self.dot(sight, toward)
        let index = body.index
        let inner = Refraction.Interface(from: .vacuum, into: index).refracted(sight, at: toward).transmission ?? sight
        let own = lens.raster(of: place)

        var length = 0.0
        var exit: Vector<3, Double>?
        if sight[2] < 0, let first = far.read(point.x, point.y) {
            length = Swift.max((first.depth - place[2]) / sight[2], 0)
            exit = first.normal
        }
        if exit != nil, inner[2] < 0 {
            var step = 0
            while step < 4 {
                guard let end = Self.drawn(Self.along(place, inner, length), own, point, lens), let found = far.read(end.x, end.y) else { break }
                exit = found.normal
                guard step < 3 else { break }
                let next = (found.depth - place[2]) / inner[2]
                guard next.isFinite else { break }
                length = Swift.max(next, 0)
                step += 1
            }
        }
        var passage = Self(
            place: place,
            sight: sight,
            toward: toward,
            exit: exit,
            point: point,
            own: own,
            cosine: cosine,
            plane: plane,
            index: index,
            inner: inner,
            read: point,
            length: length,
            leaving: sight,
            beyond: 0,
            mirrored: Refraction.reflected(sight, at: toward),
            share: surroundings == nil ? 0 : Refraction.Interface(from: .vacuum, into: index).reflectance(cosine: cosine)
        )
        let way = passage.way(within: inner, lens: lens)
        passage.read = way.read ?? point
        passage.leaving = way.out
        passage.beyond = surroundings?.share(leaving: way.out, along: sight) ?? 0
        self = passage
    }

    /// Where light of an index reads the picture: bent in by it, along the path's length, bent out by it. Where
    /// the line of sight grazes the surface, within a cosine of `grazing`, the read is drawn back toward the point
    /// itself, all the way at a cosine of 0 and not at all from `grazing` on, with no slope at either end: there a
    /// few pixels of silhouette would otherwise read far and wide, which shows as moiré, and the line along the
    /// outline covers them.
    func read(for index: Refraction.Index<Double>, lens: Picture.Renderer.CPU.Lens) -> Read {
        let read = index == self.index ? self.read : way(for: index, lens: lens).read ?? point
        guard cosine < Self.grazing else { return read }
        let share = Double.math.smoothstep(Swift.max(cosine, 0) / Self.grazing)
        return Read(x: point.x + (read.x - point.x) * share, y: point.y + (read.y - point.y) * share)
    }

    /// The cosine below which a grazing read is drawn back toward the point.
    static let grazing = 0.2

    func way(for index: Refraction.Index<Double>, lens: Picture.Renderer.CPU.Lens) -> (read: Read?, out: Vector<3, Double>) {
        let n = Swift.max(index, .vacuum)
        let within = Refraction.Interface(from: .vacuum, into: n).refracted(sight, at: toward).transmission ?? sight
        return way(within: within, index: n, lens: lens)
    }

    /// `way(for:lens:)` of the glass's own index, whose line of sight bent in is `inner`.
    func way(within: Vector<3, Double>, lens: Picture.Renderer.CPU.Lens) -> (read: Read?, out: Vector<3, Double>) {
        way(within: within, index: index, lens: lens)
    }

    /// `way(for:lens:)` of an index at least vacuum's, whose line of sight bent in is `within`.
    func way(within: Vector<3, Double>, index n: Refraction.Index<Double>, lens: Picture.Renderer.CPU.Lens) -> (read: Read?, out: Vector<3, Double>) {
        var out = within
        if let exit {
            let against = Self.dot(exit, within) > 0 ? Self.scaled(exit, -1) : exit
            out = Refraction.Interface(from: n, into: .vacuum).refracted(within, at: against).value
        }
        let leaving = Self.along(place, within, length)
        let reach = Swift.max(leaving[2] - plane, 0) / Swift.max(-out[2], 0.05)
        let end = Self.along(leaving, out, reach)
        return (Self.drawn(end, own, point, lens), out)
    }

    /// Where a place in eye space is drawn, relative to where the passage's own place is drawn.
    static func drawn(_ end: Vector<3, Double>, _ own: (x: Double, y: Double)?, _ point: Read, _ lens: Picture.Renderer.CPU.Lens) -> Read? {
        guard let own, let there = lens.raster(of: end) else { return nil }
        return Read(x: point.x + there.x - own.x, y: point.y + there.y - own.y)
    }

    static func dot(_ a: Vector<3, Double>, _ b: Vector<3, Double>) -> Double {
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    }

    static func scaled(_ a: Vector<3, Double>, _ factor: Double) -> Vector<3, Double> {
        Vector([a[0] * factor, a[1] * factor, a[2] * factor])
    }

    /// A place moved a length along a direction.
    static func along(_ place: Vector<3, Double>, _ direction: Vector<3, Double>, _ length: Double) -> Vector<3, Double> {
        Vector([place[0] + direction[0] * length, place[1] + direction[1] * length, place[2] + direction[2] * length])
    }
}
