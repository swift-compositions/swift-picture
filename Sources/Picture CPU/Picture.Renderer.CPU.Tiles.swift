import Picture

extension Picture.Renderer.CPU {
    /// Sprites sorted into square tiles of a box: each tile lists, in their original order, the sprites
    /// whose box reaches it, so a pixel sums only the sprites that can light it. Each sprite's colour is taken
    /// into a working pixel once, not at every pixel it lights.
    struct Tiles {
        let box: Box
        let lists: [[Lit]]
    }
}

extension Picture.Renderer.CPU.Tiles {
    /// The side of a tile, in pixels.
    static let side = 32

    var columns: Int { (box.width + Self.side - 1) / Self.side }

    /// The sprites sorted into the tiles of a box of raster space, under a transform from their space.
    init(_ sprites: Picture.Sprites, _ transform: Picture.Transform, over box: Picture.Renderer.CPU.Box) {
        let columns = (box.width + Self.side - 1) / Self.side
        let rows = (box.height + Self.side - 1) / Self.side
        var lists = [[Lit]](repeating: [], count: columns * rows)
        for sprite in sprites.sprites where sprite.radius > 0 {
            let lit = Lit(x: sprite.center[0], y: sprite.center[1], radius: sprite.radius, reach: sprite.radius > 0 ? sprite.radius * sprite.radius : 0, pixel: sprite.color.pixel)
            let square = Picture.Plane.Rectangle(
                llx: .init(sprite.center[0] - sprite.radius),
                lly: .init(sprite.center[1] - sprite.radius),
                urx: .init(sprite.center[0] + sprite.radius),
                ury: .init(sprite.center[1] + sprite.radius)
            )
            let reach = Picture.Renderer.CPU.Box(square, transform).expanded(1, 1).intersection(box)
            guard reach.area > 0 else { continue }
            var row = (reach.top - box.top) / Self.side
            while row <= (reach.bottom - 1 - box.top) / Self.side {
                var column = (reach.left - box.left) / Self.side
                while column <= (reach.right - 1 - box.left) / Self.side {
                    lists[row * columns + column].append(lit)
                    column += 1
                }
                row += 1
            }
        }
        self.init(box: box, lists: lists)
    }

    /// The light the sprites of a list add at a point, as `Picture.Sprites.light(at:)` sums it, sprite by sprite
    /// in their order.
    static func light(_ list: UnsafeBufferPointer<Lit>, _ profile: Picture.Sprites.Profile, at x: Double, _ y: Double) -> Picture.Pixel {
        var total = Picture.Pixel.transparent
        for unsafe sprite in unsafe list {
            let across = x - sprite.x
            let down = y - sprite.y
            let squared = across * across + down * down
            guard squared < sprite.reach else { continue }
            let coverage = profile.coverage(at: Float(squared.squareRoot() / sprite.radius))
            total = sprite.pixel.composited(over: total, operator: .lighter, coverage: coverage)
        }
        return total
    }

    /// The box of the tile at a position in the list, cut to the whole box.
    func tile(_ position: Int) -> Picture.Renderer.CPU.Box {
        let left = box.left + (position % columns) * Self.side
        let top = box.top + (position / columns) * Self.side
        return Picture.Renderer.CPU.Box(left: left, top: top, right: left + Self.side, bottom: top + Self.side).intersection(box)
    }
}
