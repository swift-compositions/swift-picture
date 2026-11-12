public import Threefry

extension Picture.Effect {
    /// Film grain: the plane is cut into square cells `size` wide, and everything in a cell is made lighter or
    /// darker by the cell's own share of `amount`, which the seed alone decides.
    ///
    /// The change is the same for red, green and blue. It is made in the sheet's linear light and scaled by
    /// each pixel's alpha, so a clear sheet stays clear, and a colour between none and its alpha stays between them.
    public struct Grain: Sendable, Hashable {
        public var seed: Threefry.Key
        public var amount: Double
        public var size: Double

        public init(seed: Threefry.Key, amount: Double, size: Double = 1) {
            self.seed = seed
            self.amount = amount
            self.size = size
        }
    }
}

extension Picture.Effect.Grain {
    /// The share of `amount` the cell that holds a point is changed by, from −1 to 1: the mean of two even
    /// draws from the seed and the cell's column and row, so shares near 0 are the most common.
    public func share(at point: Picture.Plane.Point<2>) -> Double {
        guard size > 0 else { return 0 }
        let column = (point[0] / size).rounded(.down)
        let row = (point[1] / size).rounded(.down)
        guard abs(column) < 0x1p62, abs(row) < 0x1p62 else { return 0 }
        let cell = Threefry.Block(UInt64(bitPattern: Int64(column)), UInt64(bitPattern: Int64(row)))
        let drawn = Threefry.block(key: seed, counter: cell)
        let first = Double(drawn.first >> 11) * 0x1p-53
        let second = Double(drawn.second >> 11) * 0x1p-53
        return first + second - 1
    }

    /// A pixel of the sheet at a point, changed by the grain there.
    public func pixel(_ pixel: Picture.Pixel, at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        let change = Float(amount * share(at: point)) * pixel.alpha
        func moved(_ component: Float) -> Float {
            Swift.min(Swift.max(component + change, 0), Swift.max(component, pixel.alpha))
        }
        return Picture.Pixel(
            color: .init(red: moved(pixel.color.red), green: moved(pixel.color.green), blue: moved(pixel.color.blue)),
            alpha: pixel.alpha
        )
    }
}
