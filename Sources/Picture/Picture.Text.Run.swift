extension Picture.Text {
    /// One line being laid out: a stretch of a paragraph's glyphs.
    struct Run {
        let scalars: [Unicode.Scalar]
        let indices: [UInt16]
        let shares: [Double?]
        let starts: [Double]
        let widths: [Double]
        let blank: [Bool]
        let range: Range<Int>
    }
}

extension Picture.Text.Run {
    /// The run's width up to the end of its last glyph that is not a space.
    var width: Double {
        guard let last = range.last(where: { !blank[$0] }) else { return 0 }
        return starts[last] - starts[range.lowerBound] + widths[last]
    }
}
