extension Picture.Effect {
    /// A grid of cells, one corner of one cell at `origin`, each `width` by `height`.
    public struct Pixelation: Sendable, Hashable {
        public var origin: Picture.Plane.Point<2>
        public var width: Double
        public var height: Double

        public init(origin: Picture.Plane.Point<2> = .zero, width: Double, height: Double) {
            self.origin = origin
            self.width = width
            self.height = height
        }
    }
}

extension Picture.Effect.Pixelation {
    /// The point of the sheet read for `point`: the centre of the cell that holds it.
    public func source(of point: Picture.Plane.Point<2>) -> Picture.Plane.Point<2> {
        guard width > 0, height > 0 else { return point }
        return Picture.Plane.Point<2>([
            origin[0] + (((point[0] - origin[0]) / width).rounded(.down) + 0.5) * width,
            origin[1] + (((point[1] - origin[1]) / height).rounded(.down) + 0.5) * height,
        ])
    }
}
