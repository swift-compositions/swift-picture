import Picture

extension Picture.Renderer.CPU {
    /// A rectangle of whole pixels of raster space: columns `left` up to `right`, rows `top` up to `bottom`.
    /// It may reach left of or above the raster, as a sheet with margins does.
    struct Box: Equatable {
        var left: Int
        var top: Int
        var right: Int
        var bottom: Int
    }
}

extension Picture.Renderer.CPU.Box {
    /// The box with no pixels.
    static var empty: Self { Self(left: 0, top: 0, right: 0, bottom: 0) }

    /// How far any coordinate of a box may lie from the origin.
    static let reach: Double = 1_073_741_824

    var width: Int { Swift.max(right - left, 0) }

    var height: Int { Swift.max(bottom - top, 0) }

    /// The number of pixels in the box.
    var area: Int { width * height }

    /// The smallest box whose pixels hold every point from (`low`, `high`) along x and y, or none for a bound
    /// that is not a number.
    init(x low: Double, _ high: Double, y top: Double, _ bottom: Double) {
        guard !low.isNaN, !high.isNaN, !top.isNaN, !bottom.isNaN, low <= high, top <= bottom else {
            self = .empty
            return
        }
        let reach = Self.reach
        self.init(
            left: Int(Swift.min(Swift.max(low.rounded(.down), -reach), reach)),
            top: Int(Swift.min(Swift.max(top.rounded(.down), -reach), reach)),
            right: Int(Swift.min(Swift.max(high.rounded(.up), -reach), reach)),
            bottom: Int(Swift.min(Swift.max(bottom.rounded(.up), -reach), reach))
        )
    }

    /// The box around a rectangle of some space, after a transform into raster space.
    init(_ rectangle: Picture.Plane.Rectangle, _ transform: Picture.Transform) {
        let x = (rectangle.llx.underlying, rectangle.urx.underlying)
        let y = (rectangle.lly.underlying, rectangle.ury.underlying)
        let corners = [
            transform.applied(to: Vector([x.0, y.0])),
            transform.applied(to: Vector([x.1, y.0])),
            transform.applied(to: Vector([x.0, y.1])),
            transform.applied(to: Vector([x.1, y.1])),
        ]
        let across = corners.map { $0[0] }
        let down = corners.map { $0[1] }
        guard across.allSatisfy({ !$0.isNaN }), down.allSatisfy({ !$0.isNaN }) else {
            self = .empty
            return
        }
        self.init(
            x: across.min() ?? 0,
            across.max() ?? 0,
            y: down.min() ?? 0,
            down.max() ?? 0
        )
    }

    /// The pixels in both boxes.
    func intersection(_ other: Self) -> Self {
        let result = Self(
            left: Swift.max(left, other.left),
            top: Swift.max(top, other.top),
            right: Swift.min(right, other.right),
            bottom: Swift.min(bottom, other.bottom)
        )
        return result.area > 0 ? result : .empty
    }

    /// The smallest box holding the pixels of both.
    func union(_ other: Self) -> Self {
        guard area > 0 else { return other }
        guard other.area > 0 else { return self }
        return Self(
            left: Swift.min(left, other.left),
            top: Swift.min(top, other.top),
            right: Swift.max(right, other.right),
            bottom: Swift.max(bottom, other.bottom)
        )
    }

    /// The box grown by a number of pixels on the left and right, and another above and below.
    func expanded(_ across: Int, _ down: Int) -> Self {
        guard area > 0 else { return self }
        return Self(left: left - across, top: top - down, right: right + across, bottom: bottom + down)
    }

    /// The box moved by a number of pixels across and down.
    func moved(_ across: Int, _ down: Int) -> Self {
        Self(left: left + across, top: top + down, right: right + across, bottom: bottom + down)
    }

    /// The pixel's position in a row-by-row list of the box's pixels.
    func index(_ x: Int, _ y: Int) -> Int {
        (y - top) * width + (x - left)
    }

    /// Whether the pixel lies in the box.
    func contains(_ x: Int, _ y: Int) -> Bool {
        x >= left && x < right && y >= top && y < bottom
    }

    /// The box as a region of a raster whose first pixel is the box's own.
    var region: Raster<Float>.Region {
        Raster<Float>.Region(x: .zero, y: .zero, width: Cardinal(UInt(width)), height: Cardinal(UInt(height)))
    }
}
