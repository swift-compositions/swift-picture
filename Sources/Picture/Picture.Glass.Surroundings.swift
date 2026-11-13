public import Vector

extension Picture.Glass {
    /// What is around a scene for its glass to mirror, and to show where light leaves it too far aside to meet
    /// the picture behind: one colour overhead and one underfoot, running into each other at the horizon.
    public struct Surroundings: Sendable, Hashable {
        /// The colour straight up, in eye space, where y points up.
        public var above: Picture.Color

        /// The colour straight down.
        public var below: Picture.Color

        /// How far to each side of the line of sight the picture behind reaches, as a multiple of how far
        /// behind it stands: light that leaves the glass pointing further aside shows the surroundings. The
        /// picture reaches everywhere when this is infinite.
        public var width: Double

        public init(above: Picture.Color, below: Picture.Color, width: Double = .infinity) {
            self.above = above
            self.below = below
            self.width = width
        }
    }
}

extension Picture.Glass.Surroundings {
    /// How much of `above` a direction shows, 0 straight down to 1 straight up, level at both ends: for a
    /// direction whose unit length has the height h, s²(3 - 2s) with s = (h + 1) / 2. A half for no direction.
    public static func share(toward direction: Vector<3, Double>) -> Double {
        let length = (direction[0] * direction[0] + direction[1] * direction[1] + direction[2] * direction[2]).squareRoot()
        guard length > 0, length.isFinite else { return 0.5 }
        let s = Swift.min(Swift.max((direction[1] / length + 1) / 2, 0), 1)
        return s * s * (3 - 2 * s)
    }

    /// The working pixel the surroundings show in a direction: `below` mixed toward `above` by the share.
    public func pixel(toward direction: Vector<3, Double>) -> Picture.Pixel {
        below.pixel.interpolated(to: above.pixel, at: Float(Self.share(toward: direction)))
    }

    /// How much of the surroundings, 0 to 1, light shows that leaves the glass in a unit direction `leaving`
    /// when the unit line of sight is `sight`: nothing while the tangent of the angle between them is within
    /// seven tenths of `width`, everything from `width` on, and level at both ends between.
    public func share(leaving: Vector<3, Double>, along sight: Vector<3, Double>) -> Double {
        guard width.isFinite else { return 0 }
        let cosine = leaving[0] * sight[0] + leaving[1] * sight[1] + leaving[2] * sight[2]
        guard cosine > 0 else { return 1 }
        let tangent = Swift.max(1 - cosine * cosine, 0).squareRoot() / cosine
        let start = 0.7 * width
        guard tangent > start else { return 0 }
        guard tangent < width else { return 1 }
        let s = (tangent - start) / (width - start)
        return s * s * (3 - 2 * s)
    }
}
