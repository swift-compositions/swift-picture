extension Picture.Effect.Kaleidoscope {
    /// A line of a colour along every mirror edge of a kaleidoscope, `width` units of the layer's space across,
    /// centred on the edge.
    public struct Seam: Sendable, Hashable {
        public var color: Picture.Color
        public var width: Double

        public init(_ color: Picture.Color, width: Double) {
            self.color = color
            self.width = width
        }
    }
}
