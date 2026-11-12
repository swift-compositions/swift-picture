import Picture

extension Picture.Renderer.CPU {
    /// What light does at one point of glass with a body: where in the raster each colour reads the picture
    /// behind after going in at the point and out of the far side, the direction the surface mirrors there, and
    /// the share of light it mirrors.
    struct Passage {
        var reads: InlineArray<3, Read>

        /// How far the light travels inside the body, in the scene's units.
        var length: Double

        /// The direction green light leaves the far side in, and the share of it that misses the picture behind.
        var leaving: Vector<3, Double>
        var beyond: Double
        var mirrored: Vector<3, Double>
        var share: Double
    }
}

extension Picture.Renderer.CPU.Passage {
    /// The line of sight is bent into the body at `place`, a point of the near side in eye space with the unit
    /// normal `normal`. Where it leaves is found on the far side as drawn: the path's length starts as the
    /// body's thickness along the line of sight and is corrected three times to end at the far side's depth
    /// where the path's end is drawn. There the light is bent out again by the far side's normal, or mirrored
    /// back in where none can leave, and reads the picture where it meets a plane the refraction's distance
    /// behind. Green finds the way; red and blue follow paths of the same length under their own indices.
    /// Where no far side is found the light goes straight on, and a place that cannot be drawn reads at `point`.
    /// Places are drawn relative to where `place` itself is drawn, so that light going straight on reads at
    /// `point` exactly.
    init(
        from place: Vector<3, Double>,
        normal: Vector<3, Double>,
        at point: Read,
        through refraction: Picture.Scene.Material.Glass.Refraction,
        lens: Picture.Renderer.CPU.Lens,
        far: Picture.Renderer.CPU.Far
    ) {
        let sight = lens.sight(through: place)
        let toward = Self.dot(normal, sight) > 0 ? Self.scaled(normal, -1) : normal
        let cosine = -Self.dot(sight, toward)
        let indices = refraction.indices
        let inner = Picture.Scene.Material.Glass.Refraction.bent(sight, at: toward, ratio: 1 / indices[1]) ?? sight

        let own = lens.raster(of: place)
        func drawn(_ end: Vector<3, Double>) -> Read? {
            guard let own, let there = lens.raster(of: end) else { return nil }
            return Read(x: point.x + there.x - own.x, y: point.y + there.y - own.y)
        }

        var length = 0.0
        var leaving: Vector<3, Double>?
        if sight[2] < 0, let first = far.read(point.x, point.y) {
            length = Swift.max((first.depth - place[2]) / sight[2], 0)
            leaving = first.normal
        }
        if leaving != nil, inner[2] < 0 {
            var step = 0
            while step < 4 {
                guard let end = drawn(Self.along(place, inner, length)), let found = far.read(end.x, end.y) else { break }
                leaving = found.normal
                guard step < 3 else { break }
                let next = (found.depth - place[2]) / inner[2]
                guard next.isFinite else { break }
                length = Swift.max(next, 0)
                step += 1
            }
        }

        var reads = InlineArray<3, Read>(repeating: point)
        var away = sight
        var channel = 0
        while channel < 3 {
            let within = channel == 1 ? inner : Picture.Scene.Material.Glass.Refraction.bent(sight, at: toward, ratio: 1 / indices[channel]) ?? sight
            var out = within
            if let leaving {
                let against = Self.dot(leaving, within) > 0 ? Self.scaled(leaving, -1) : leaving
                out =
                    Picture.Scene.Material.Glass.Refraction.bent(within, at: against, ratio: indices[channel])
                    ?? Picture.Scene.Material.Glass.Refraction.mirrored(within, at: against)
            }
            if channel == 1 { away = out }
            let reach = refraction.distance / Swift.max(-out[2], 0.05)
            let end = Self.along(Self.along(place, within, length), out, reach)
            if let read = drawn(end) { reads[channel] = read }
            channel += 1
        }
        self.init(
            reads: reads,
            length: length,
            leaving: away,
            beyond: refraction.surroundings?.share(leaving: away, along: sight) ?? 0,
            mirrored: Picture.Scene.Material.Glass.Refraction.mirrored(sight, at: toward),
            share: refraction.surroundings == nil ? 0 : refraction.reflectance(cosine: cosine)
        )
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
