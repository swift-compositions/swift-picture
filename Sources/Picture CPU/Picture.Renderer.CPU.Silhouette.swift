import Picture
import Synchronization

extension Picture.Renderer.CPU {
    /// The outline of a scene's glass as drawn, over a box of raster space: at `fine` × `fine` points to a pixel,
    /// whether glass is the nearest thing there, and from that the signed distance in pixels to the outline,
    /// negative inside, found by a two-pass sweep that carries each point's nearest point across the outline
    /// (Danielsson's vector distance), so it is the Euclidean distance between points up to a fraction of a step.
    struct Silhouette {
        static let fine = 2

        let box: Box
        let columns: Int
        let rows: Int
        let distances: [Float]
    }
}

extension Picture.Renderer.CPU.Silhouette {
    init(_ box: Picture.Renderer.CPU.Box, inside: [Bool], _ workers: Picture.Renderer.CPU.Workers = .one) {
        let fine = Self.fine
        let columns = box.width * fine
        let rows = box.height * fine
        let far = Int32(1 << 20)
        func sweep(_ target: Bool) -> [Float] {
            // For each point, the offset to the nearest point whose `inside` is `target`.
            var dx = [Int32](repeating: far, count: columns * rows)
            var dy = [Int32](repeating: far, count: columns * rows)
            for index in 0..<(columns * rows) where inside[index] == target {
                dx[index] = 0
                dy[index] = 0
            }
            func length(_ x: Int32, _ y: Int32) -> Int64 { Int64(x) * Int64(x) + Int64(y) * Int64(y) }
            func relax(_ index: Int, _ other: Int, _ stepX: Int32, _ stepY: Int32) {
                guard dx[other] != far else { return }
                let x = dx[other] + stepX
                let y = dy[other] + stepY
                if dx[index] == far || length(x, y) < length(dx[index], dy[index]) {
                    dx[index] = x
                    dy[index] = y
                }
            }
            for row in 0..<rows {
                for column in 0..<columns {
                    let index = row * columns + column
                    if row > 0 {
                        relax(index, index - columns, 0, 1)
                        if column > 0 { relax(index, index - columns - 1, 1, 1) }
                        if column + 1 < columns { relax(index, index - columns + 1, -1, 1) }
                    }
                    if column > 0 { relax(index, index - 1, 1, 0) }
                }
                for column in stride(from: columns - 1, through: 0, by: -1) where column + 1 < columns {
                    let index = row * columns + column
                    relax(index, index + 1, -1, 0)
                }
            }
            for row in stride(from: rows - 1, through: 0, by: -1) {
                for column in stride(from: columns - 1, through: 0, by: -1) {
                    let index = row * columns + column
                    if row + 1 < rows {
                        relax(index, index + columns, 0, -1)
                        if column + 1 < columns { relax(index, index + columns + 1, -1, -1) }
                        if column > 0 { relax(index, index + columns - 1, 1, -1) }
                    }
                    if column + 1 < columns { relax(index, index + 1, -1, 0) }
                }
                for column in 0..<columns where column > 0 {
                    let index = row * columns + column
                    relax(index, index - 1, 1, 0)
                }
            }
            return (0..<(columns * rows)).map { index in
                dx[index] == far ? Float.infinity : Float(Double(length(dx[index], dy[index])).squareRoot())
            }
        }
        let sweeps = Mutex<[[Float]]>([[], []])
        workers.run(2) { part in
            let result = sweep(part == 1)
            sweeps.withLock { $0[part] = result }
        }
        let (toOutside, toInside) = sweeps.withLock { ($0[0], $0[1]) }
        let scale = Float(fine)
        let distances = (0..<(columns * rows)).map { index in
            inside[index] ? -(toOutside[index] - 0.5) / scale : (toInside[index] - 0.5) / scale
        }
        self.init(box: box, columns: columns, rows: rows, distances: distances)
    }

    /// The signed distance in pixels at a point of raster space, read bilinearly between the fine points; far
    /// outside the box, infinite.
    func distance(_ x: Double, _ y: Double) -> Double {
        guard columns > 0, rows > 0, x.isFinite, y.isFinite else { return .infinity }
        let fine = Double(Self.fine)
        let across = (x - Double(box.left)) * fine - 0.5
        let down = (y - Double(box.top)) * fine - 0.5
        guard across > -2, down > -2, across < Double(columns + 1), down < Double(rows + 1) else { return .infinity }
        let column = Swift.min(Swift.max(Int(across.rounded(.down)), 0), columns - 1)
        let row = Swift.min(Swift.max(Int(down.rounded(.down)), 0), rows - 1)
        let next = (Swift.min(column + 1, columns - 1), Swift.min(row + 1, rows - 1))
        let u = Float(Swift.min(Swift.max(across - Double(column), 0), 1))
        let v = Float(Swift.min(Swift.max(down - Double(row), 0), 1))
        let a = distances[row * columns + column]
        let b = distances[row * columns + next.0]
        let c = distances[next.1 * columns + column]
        let d = distances[next.1 * columns + next.0]
        guard a.isFinite, b.isFinite, c.isFinite, d.isFinite else { return Double(Swift.min(a, b, c, d)) }
        let top = a + (b - a) * u
        let bottom = c + (d - c) * u
        return Double(top + (bottom - top) * v)
    }
}
