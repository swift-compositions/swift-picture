extension Picture.Text {
    /// A height of a line, measured up from its baseline by the font's metrics: the line a text is put at.
    public enum Level: Sendable, Hashable {
        /// The baseline itself.
        case baseline

        /// The font's ascent above the baseline.
        case ascent

        /// The font's descent below the baseline.
        case descent

        /// A share of the cap height: 1 is the top of the capitals, ½ their middle.
        case cap(Double)

        /// A share of the x-height: 1 is the top of the lowercase, ½ its middle.
        case ex(Double)
    }
}

extension Picture.Text.Level {
    /// How far the level stands above the baseline, by a font's metrics: below it for the descent.
    public func height(in metrics: Picture.Text.Metrics) -> Double {
        switch self {
        case .baseline: 0
        case .ascent: metrics.ascent
        case .descent: -metrics.descent
        case .cap(let share): share * metrics.cap
        case .ex(let share): share * metrics.ex
        }
    }
}
