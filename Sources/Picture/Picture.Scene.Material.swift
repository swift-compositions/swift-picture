extension Picture.Scene {
    /// What a model's mesh is drawn as.
    public enum Material: Sendable, Hashable {
        /// Every face filled with one colour, unlit.
        case flat(Picture.Color)

        /// Every edge of every face as a line `width` picture units wide.
        case wireframe(Picture.Color, width: Double)

        /// Every vertex as a disc of `radius` picture units.
        case points(Picture.Color, radius: Double)

        /// Every face showing what is behind it, bent by the surface. For a glass with a body, the picture behind
        /// stands `distance` picture units behind the plane across the line of sight through the model's farthest
        /// point from the eye.
        case glass(Picture.Glass, distance: Double = 1)

        /// Every point of every face in the colour a lamp and a rim light give it, from the surface's normal there.
        case shaded(Shade)
    }
}
