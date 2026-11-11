extension Picture.Gradient {
    /// A colour at a parameter.
    public struct Stop: Sendable, Hashable {
        public var offset: Float
        public var color: Picture.Color

        public init(offset: Float, color: Picture.Color) {
            self.offset = offset
            self.color = color
        }
    }
}
