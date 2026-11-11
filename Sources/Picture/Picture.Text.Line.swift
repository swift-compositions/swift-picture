extension Picture.Text {
    /// One line of a text.
    public struct Line: Sendable, Hashable {
        /// The line's glyphs, left to right.
        public let glyphs: [Glyph]

        /// The y of the line's baseline.
        public let baseline: Double

        /// The line's width up to the end of its last glyph that is not a space.
        public let width: Double
    }
}
