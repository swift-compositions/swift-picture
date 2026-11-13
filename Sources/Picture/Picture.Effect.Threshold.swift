extension Picture.Effect {
    /// What of a sheet is brighter than a level: each pixel scaled down to the light it has above `level`,
    /// eased in over `knee` so that no edge appears where the level is crossed. The light that blooms.
    ///
    /// A pixel's brightness is the largest of its red, green and blue as a working pixel, in linear light and
    /// multiplied by alpha, so a saturated colour counts as fully as white of the same strength. The light
    /// kept, `kept(_:)`, is 0 up to `level`, `(b − level)² / (2 · knee)` over the knee, and `b − level − knee / 2`
    /// from `level + knee` on: it and its slope are continuous, and it only grows with the brightness. The pixel
    /// keeps its hue: colour and alpha alike are multiplied by the kept light over the brightness.
    public struct Threshold: Sendable, Hashable {
        public var level: Float
        public var knee: Float

        public init(level: Float = 0.5, knee: Float = 0.5) {
            self.level = level
            self.knee = knee
        }
    }
}

extension Picture.Effect.Threshold {
    /// The light kept of a brightness: none up to `level`, eased in over `knee`, and all above `level` less
    /// half the knee from `level + knee` on. A knee that is not positive is a straight cut at the level.
    public func kept(_ brightness: Float) -> Float {
        let above = brightness - level
        guard above > 0 else { return 0 }
        guard knee > 0, above < knee else { return above - Swift.max(knee, 0) / 2 }
        return above * above / (2 * knee)
    }

    /// A pixel of the sheet with only its light above the level: colour and alpha multiplied by `kept(_:)` of
    /// its brightness over that brightness, never more than the pixel. A pixel with no brightness gives none.
    public func pixel(_ pixel: Picture.Pixel) -> Picture.Pixel {
        let brightness = Swift.max(pixel.color.red, pixel.color.green, pixel.color.blue)
        guard brightness > 0 else { return .transparent }
        let share = Swift.min(kept(brightness) / brightness, 1)
        guard share > 0 else { return .transparent }
        return Picture.Pixel(
            color: .init(red: pixel.color.red * share, green: pixel.color.green * share, blue: pixel.color.blue * share),
            alpha: pixel.alpha * share
        )
    }
}
