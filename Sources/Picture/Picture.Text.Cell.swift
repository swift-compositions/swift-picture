extension Picture.Text {
    /// A glyph set in a share of a figure cell, whose outline is centred there once for every use.
    struct Cell: Hashable {
        let index: UInt16
        let share: Double
    }
}
