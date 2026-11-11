public import ISO_14496_22

extension Picture.Text {
    /// Why a string could not be set.
    public enum Error: Swift.Error, Sendable, Hashable {
        /// The font's bytes do not parse, or its kerning data is damaged.
        case font(ISO_14496_22.FontFile.ParsingError)

        /// A glyph's outline cannot be read.
        case outline(ISO_14496_22.Outline.Error)

        /// The size is not a positive, finite number.
        case size

        /// The measure is not a positive, finite number.
        case measure

        /// The font says an em has no units.
        case units
    }
}
