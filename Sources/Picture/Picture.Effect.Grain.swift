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
    /// The cell that holds a point: its column and row in the grid, whole numbers. It is nil for a grain
    /// whose cells have no size and for a point further than 2⁶² cells from the origin.
    public func cell(at point: Picture.Plane.Point<2>) -> Cell? {
        guard size > 0 else { return nil }
        let column = (point[0] / size).rounded(.down)
        let row = (point[1] / size).rounded(.down)
        guard abs(column) < 0x1p62, abs(row) < 0x1p62 else { return nil }
        return Cell(column: column, row: row)
    }

    /// The share of `amount` a cell is changed by, from −1 to 1: the mean of two even draws from the seed
    /// and the cell's column and row, so shares near 0 are the most common.
    public func share(of cell: Cell) -> Double {
        let counter = Threefry.Block(UInt64(bitPattern: Int64(cell.column)), UInt64(bitPattern: Int64(cell.row)))
        let drawn = Threefry.block(key: seed, counter: counter)
        let units = drawn.units(as: Double.self)
        return units.first + units.second - 1
    }

    /// The share of `amount` the cell that holds a point is changed by, and 0 where no cell does.
    public func share(at point: Picture.Plane.Point<2>) -> Double {
        cell(at: point).map(share(of:)) ?? 0
    }

    /// A pixel of the sheet in a cell of a given share, changed by the grain.
    public func pixel(_ pixel: Picture.Pixel, share: Double) -> Picture.Pixel {
        let change = Float(amount * share) * pixel.alpha
        func moved(_ component: Float) -> Float {
            Swift.min(Swift.max(component + change, 0), Swift.max(component, pixel.alpha))
        }
        return Picture.Pixel(
            color: .init(red: moved(pixel.color.red), green: moved(pixel.color.green), blue: moved(pixel.color.blue)),
            alpha: pixel.alpha
        )
    }

    /// A pixel of the sheet at a point, changed by the grain there.
    public func pixel(_ pixel: Picture.Pixel, at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        self.pixel(pixel, share: share(at: point))
    }
}
