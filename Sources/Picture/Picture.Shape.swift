extension Picture {
    /// A path with a fill, a stroke or both. The fill is drawn first and the stroke on top of it.
    public struct Shape: Sendable, Hashable {
        public var path: Picture.Plane.Path
        public var fill: Fill?
        public var stroke: Stroke?

        public init(_ path: Picture.Plane.Path, fill: Fill? = nil, stroke: Stroke? = nil) {
            self.path = path
            self.fill = fill
            self.stroke = stroke
        }
    }
}
