extension Picture.Text {
    /// How the digits U+0030 to U+0039, and the characters set among them, are set.
    public enum Figures: Sendable, Hashable {
        /// Each digit on its own advance, kerned like any other glyph.
        case proportional

        /// Every digit on one advance, the widest digit's, its outline centred in it, and no kerning on either
        /// side of a digit: a number's width depends only on how many digits it has, so a counting number
        /// does not jitter. Every other character keeps its own advance; it is `cells` of `Cells()`.
        case tabular

        /// Every digit in one figure cell, as `tabular` sets it, and each other character in the share of a cell
        /// its class is given, its outline centred there and no kerning on either side, or on its own advance
        /// where its class is given none. So a number such as 6.4 whose point stands in half a cell keeps every
        /// digit where it was as the number changes.
        case cells(Cells)
    }
}

extension Picture.Text.Figures {
    /// The share of a figure cell a character is set in, nil for its own advance: 1 for a digit unless the
    /// figures are proportional, and for `cells` the share its class is given.
    public func share(of scalar: Unicode.Scalar) -> Double? {
        switch self {
        case .proportional: return nil
        case .tabular: return Cells().share(of: scalar)
        case .cells(let cells): return cells.share(of: scalar)
        }
    }
}
