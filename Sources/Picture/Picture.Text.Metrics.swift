import Geometry
public import ISO_14496_22

extension Picture.Text {
    /// The heights and widths a font gives at a size, each in picture units: how far the font rises and falls
    /// about a baseline, the gap it asks between lines, how high its capitals and its lowercase x stand, the
    /// advance its figures share when they are tabular, and its one advance when every glyph has the same.
    public struct Metrics: Sendable, Hashable {
        /// The size the metrics are taken at, the size of an em.
        public let size: Double

        /// How far the font rises above a baseline: the `hhea` ascender.
        public let ascent: Double

        /// How far the font falls below a baseline: minus the `hhea` descender.
        public let descent: Double

        /// The gap the font asks between one line's descent and the next line's ascent: the `hhea` line gap.
        public let gap: Double

        /// The height of the capitals above the baseline, CSS's `cap`: the `OS/2` cap height, or the top of the
        /// capital H's outline where the table does not give one.
        public let cap: Double

        /// The height of the lowercase above the baseline, CSS's `ex`: the `OS/2` x-height, or the top of the
        /// lowercase x's outline where the table does not give one.
        public let ex: Double

        /// The advance of a tabular figure: the widest advance of the ten digits U+0030 to U+0039.
        public let figure: Double

        /// The advance every glyph has when the font says it is fixed pitch, and nil when it does not.
        public let pitch: Double?
    }
}

extension Picture.Text.Metrics {
    /// The metrics of a font at a size.
    ///
    /// The cap height and the x-height come from the `OS/2` table when it is of version 2 or later and gives a
    /// positive height. Otherwise each is measured, as typographers do, from the top of a flat-topped glyph's
    /// outline: the capital H (U+0048) for the cap height and the lowercase x (U+0078) for the x-height. A font
    /// that maps no such glyph, or whose glyph has no outline, falls back to the ascent for the cap height and
    /// to the cap height for the x-height. A font is fixed pitch when its `post` table says so or its PANOSE
    /// says a Latin text face of monospaced proportion; its pitch is then the advance of the space (U+0020),
    /// or of glyph 0 when it maps no space.
    public init(font: ISO_14496_22.FontFile, size: Double) throws(Picture.Text.Error) {
        guard size > 0, size.isFinite else { throw .size }
        guard font.unitsPerEm > 0 else { throw .units }
        let scale = size / Double(font.unitsPerEm)
        func height(_ given: Int16?, measuring scalar: UInt32, otherwise fallback: Double) throws(Picture.Text.Error) -> Double {
            if let given, given > 0 { return Double(given) }
            guard let index = font.glyphIndex(for: scalar) else { return fallback }
            let outline: Geometry<Double, ISO_14496_22.Unit>.Path
            do throws(ISO_14496_22.Outline.Error) {
                outline = try font.outline(for: index)
            } catch {
                throw .outline(error)
            }
            guard let box = outline.boundingBox, box.ury.underlying > 0 else { return fallback }
            return box.ury.underlying
        }
        let ascent = Double(font.ascender)
        let cap = try height(font.os2?.sCapHeight, measuring: 0x48, otherwise: ascent)
        let ex = try height(font.os2?.sxHeight, measuring: 0x78, otherwise: cap)
        let digits = (0x30...0x39).map { (scalar: UInt32) in font.advanceWidth(for: font.glyphIndex(for: scalar) ?? 0) }
        let panose = font.os2?.panose ?? []
        let fixed = font.isFixedPitch || (panose.count > 3 && panose[0] == 2 && panose[3] == 9)
        self.size = size
        self.ascent = ascent * scale
        self.descent = -Double(font.descender) * scale
        self.gap = Double(font.lineGap) * scale
        self.cap = cap * scale
        self.ex = ex * scale
        self.figure = Double(digits.max() ?? 0) * scale
        self.pitch = fixed ? Double(font.advanceWidth(for: font.glyphIndex(for: 0x20) ?? 0)) * scale : nil
    }
}
