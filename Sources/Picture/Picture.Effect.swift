extension Picture {
    /// A change to a layer's finished sheet, read as a picture on the whole plane.
    public enum Effect: Sendable, Hashable {
        /// A Gaussian blur.
        case blur(Blur)

        /// A blur along the lines through a centre.
        case zoom(Zoom)

        /// Red, green and blue moved apart.
        case chromatic(Chromatic)

        /// Every cell of a grid filled with what is at its centre.
        case pixelation(Pixelation)

        /// One wedge around a centre, mirrored and repeated all the way round.
        case kaleidoscope(Kaleidoscope)

        /// Every point read from a place a smooth noise field pushes it to.
        case displacement(Displacement)

        /// Everything near a centre turned about it, most at the centre.
        case swirl(Swirl)
    }
}
