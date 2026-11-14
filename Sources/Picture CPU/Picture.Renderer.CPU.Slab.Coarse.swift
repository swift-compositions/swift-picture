import Picture

extension Picture.Renderer.CPU.Slab {
    /// A region's signed distance in pixels at every eighth pixel centre of a box, from which the distance at
    /// any pixel of the box is bounded: a signed distance changes by at most the distance moved, so a pixel lies
    /// within half a cell's diagonal of the distance at the nearest point kept.
    struct Coarse {
        static let step = 8

        let box: Picture.Renderer.CPU.Box
        let columns: Int
        let distances: [Double]
    }
}

extension Picture.Renderer.CPU.Slab.Coarse {
    init(_ region: Picture.Plane.Region, over box: Picture.Renderer.CPU.Box, _ inverse: Picture.Transform, scale: Double) {
        let step = Self.step
        let columns = (box.width + step - 1) / step + 1
        let rows = (box.height + step - 1) / step + 1
        var distances = [Double](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = Double(box.left + column * step) + 0.5
                let y = Double(box.top + row * step) + 0.5
                distances[row * columns + column] = region.distance(to: Picture.Renderer.CPU.point(inverse, x, y)) * scale
            }
        }
        self.init(box: box, columns: columns, distances: distances)
    }

    /// The least and the most the distance in pixels can be at a pixel of the box.
    func bound(_ x: Int, _ y: Int) -> (lower: Double, upper: Double) {
        let step = Self.step
        let column = (x - box.left + step / 2) / step
        let row = (y - box.top + step / 2) / step
        let index = row * columns + column
        guard column >= 0, row >= 0, column < columns, index < distances.count else { return (-.infinity, .infinity) }
        let d = distances[index]
        let slack = Double(step) * 0.7072
        return (d - slack, d + slack)
    }
}
