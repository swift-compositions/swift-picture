extension Picture.Scene {
    /// What a model's mesh is drawn as.
    public enum Material: Sendable, Hashable {
        /// Every face filled with one colour, unlit.
        case flat(Picture.Color)

        /// Every edge of every face as a line `width` picture units wide.
        case wireframe(Picture.Color, width: Double)

        /// Every vertex as a disc of `radius` picture units.
        case points(Picture.Color, radius: Double)

        /// Every face showing what is behind it, bent by the surface.
        case glass(Picture.Glass)
    }
}
