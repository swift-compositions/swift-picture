extension Picture {
    /// One thing a picture draws.
    public indirect enum Element: Sendable, Hashable {
        /// A path, filled, stroked or both.
        case shape(Shape)

        /// Round sprites that add their light to what is behind them.
        case sprites(Sprites)

        /// Meshes seen through a camera.
        case scene(Scene)

        /// A picture moved by a transform and limited to a clip, drawn straight onto what is behind.
        case group(Group)

        /// A picture drawn on its own, changed by effects, and then put onto what is behind as one.
        case layer(Layer)
    }
}
