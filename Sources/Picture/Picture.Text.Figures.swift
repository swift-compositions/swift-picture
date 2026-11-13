extension Picture.Text {
    /// How the digits U+0030 to U+0039 are set.
    public enum Figures: Sendable, Hashable, CaseIterable {
        /// Each digit on its own advance, kerned like any other glyph.
        case proportional

        /// Every digit on one advance, the widest digit's, its outline centred in it, and no kerning on either
        /// side of a digit: a number's width depends only on how many digits it has, so a counting number
        /// does not jitter.
        case tabular
    }
}
