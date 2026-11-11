import Matrix
import Vector

extension Picture.Text {
    /// One glyph of a text: which, where, and its outline.
    public struct Glyph: Sendable, Hashable {
        /// The code point the glyph stands for.
        public let scalar: Unicode.Scalar

        /// The glyph's number in the font.
        public let index: UInt16

        /// The glyph's own origin: where the pen stood on the baseline.
        public let origin: Picture.Point

        /// The glyph's own advance width at the text's size, without kerning.
        public let advance: Double

        /// The glyph's outline around its own origin, at the text's size, upright.
        public let outline: Picture.Path
    }
}

extension Picture.Text.Glyph {
    /// The outline at the glyph's place in the text.
    public var path: Picture.Path {
        outline.transformed(by: .translation(Vector([origin[0], origin[1]])))
    }
}
