import Picture

extension Picture.Renderer.CPU {
    /// How a pane of glass is drawn.
    enum Slab {}
}

extension Picture.Renderer.CPU.Slab {
    /// The box of raster space outside which a pane under a transform draws nothing: its region's, grown by its
    /// shadows' offsets and four times their softness, and a pixel.
    static func bounds(of pane: Picture.Glass.Pane, _ transform: Picture.Transform) -> Picture.Renderer.CPU.Box {
        guard let rectangle = pane.region.boundingBox else { return .empty }
        var reach = 0.0
        for shadow in pane.shadows {
            reach = Swift.max(reach, abs(shadow.offset[0]) + abs(shadow.offset[1]) + 4 * Swift.max(shadow.softness, 0))
        }
        guard reach.isFinite else { return .empty }
        let grown = Picture.Plane.Rectangle(
            llx: .init(rectangle.llx.underlying - reach),
            lly: .init(rectangle.lly.underlying - reach),
            urx: .init(rectangle.urx.underlying + reach),
            ury: .init(rectangle.ury.underlying + reach)
        )
        return Picture.Renderer.CPU.Box(grown, transform).expanded(1, 1)
    }
}

extension Picture.Renderer.CPU.Slab {
    /// How far from a point of a pane its glass reads, in the pane's units: the largest offset of a passage across
    /// the rim from half a pixel in, where the bend is steepest, to the level middle. Reads nearer the boundary,
    /// which bend further, find the frost's nearest edge pixel.
    static func reach(of pane: Picture.Glass.Pane, scale: Double) -> Double {
        var largest = 0.0
        if case .skin(let bend) = pane.glass.surface { largest = abs(bend) }
        let start = 0.5 / scale
        let steps = 64
        for step in 0...steps {
            let inward = start + (Swift.max(pane.rim, start) - start) * Double(step) / Double(steps)
            let passage = Picture.Glass.Pane.Passage(through: pane, for: .init(distance: -inward, gradient: Vector([1, 0])))
            let index = pane.glass.body?.index(at: Picture.Glass.Spectrum.range.lowerBound) ?? .vacuum
            let offset = passage.offset(for: index)
            let length = (offset[0] * offset[0] + offset[1] * offset[1]).squareRoot()
            if length.isFinite { largest = Swift.max(largest, length) }
        }
        return largest
    }

    /// A region equal to the given one that shares no storage with it, so that the threads that each sample a
    /// copy of their own do not contend for the count of one shared array.
    static func unshared(_ region: Picture.Plane.Region) -> Picture.Plane.Region {
        guard case .union(let regions, let radius) = region else { return region }
        var copies: [Picture.Plane.Region] = []
        copies.reserveCapacity(regions.count)
        for part in regions { copies.append(unshared(part)) }
        return .union(copies, radius: radius)
    }
}
