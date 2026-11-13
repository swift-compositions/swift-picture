extension Picture.Text {
    /// Which side of a circle the tops of the glyphs face.
    public enum Side: Sendable, Hashable, CaseIterable {
        /// Tops away from the centre: the text runs the way a positive angle turns, clockwise on a screen, and
        /// stands upright along the top of the circle.
        case outside

        /// Tops toward the centre: the text runs against a positive angle, counterclockwise on a screen, and
        /// stands upright along the bottom of the circle.
        case inside
    }
}
