extension Picture.Reading {
    /// One closed or open run of a path: the kind of each segment, 1 for a line and the number of control points
    /// for a Bézier curve, and every point it passes through or is pulled by, x then y.
    struct Contour: Sendable, Hashable {
        var kinds: [Int]
        var points: [Double]
    }
}

extension Picture.Reading.Contour {
    /// A subpath's contour, nil for one with an arc, or with kinds none of `known` has.
    init?(_ subpath: Picture.Plane.Path.Subpath, among known: Set<[Int]>? = nil) {
        var kinds: [Int] = []
        kinds.reserveCapacity(subpath.segments.count)
        for segment in subpath.segments {
            switch segment {
            case .line: kinds.append(1)
            case .bezier(let bezier): kinds.append(bezier.controlPoints.count)
            case .arc, .ellipticalArc: return nil
            }
        }
        if let known, !known.contains(kinds) { return nil }
        var points = [subpath.startPoint[0], subpath.startPoint[1]]
        points.reserveCapacity(2 + 2 * kinds.reduce(0, +))
        for segment in subpath.segments {
            switch segment {
            case .line(let line):
                points += [line.end[0], line.end[1]]

            case .bezier(let bezier):
                for point in bezier.controlPoints.dropFirst() { points += [point[0], point[1]] }

            case .arc, .ellipticalArc:
                return nil
            }
        }
        self.init(kinds: kinds, points: points)
    }
}
