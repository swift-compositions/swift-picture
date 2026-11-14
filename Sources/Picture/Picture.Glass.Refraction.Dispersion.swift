extension Picture.Glass.Refraction {
    /// Named strengths of dispersion, as Abbe numbers for the Abbe number of `Picture.Glass.Refraction.medium`.
    public enum Dispersion {
        /// One index for every wavelength: no colours part.
        public static let none: Double = .infinity

        /// Between crown glass, about 60, and dense flint, about 30: colours part only where the bend is steep, as a
        /// faint fringe. The default.
        public static let subtle: Double = 45

        /// Far past any optical glass: every lensed edge fans into a full rainbow.
        public static let generous: Double = 6
    }
}
