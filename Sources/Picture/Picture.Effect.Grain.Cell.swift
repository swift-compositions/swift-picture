extension Picture.Effect.Grain {
    /// A cell of a grain's grid: its column and its row, counted from the cell whose corner is the origin.
    public struct Cell: Sendable, Hashable {
        public var column: Double
        public var row: Double

        public init(column: Double, row: Double) {
            self.column = column
            self.row = row
        }
    }
}
