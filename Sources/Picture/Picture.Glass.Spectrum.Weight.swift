extension Picture.Glass.Spectrum {
    /// A wavelength's share of red, green and blue.
    public struct Weight: Sendable, Hashable {
        public var red: Float
        public var green: Float
        public var blue: Float

        public init(red: Float, green: Float, blue: Float) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }
}
