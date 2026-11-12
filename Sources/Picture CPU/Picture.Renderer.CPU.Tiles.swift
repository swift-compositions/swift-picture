import Picture

extension Picture.Renderer.CPU {
    /// Sprites sorted into square tiles of a box: each tile lists, in their original order, the sprites
    /// whose box reaches it, so a pixel sums only the sprites that can light it.
    struct Tiles {
        let box: Box
        let lists: [[Picture.Sprites.Sprite]]
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
        var lists = [[Picture.Sprites.Sprite]](repeating: [], count: columns * rows)
        for sprite in sprites.sprites where sprite.radius > 0 {
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
                    lists[row * columns + column].append(sprite)
                    column += 1
                }
                row += 1
            }
        }
        self.init(box: box, lists: lists)
    }

    /// The box of the tile at a position in the list, cut to the whole box.
    func tile(_ position: Int) -> Picture.Renderer.CPU.Box {
        let left = box.left + (position % columns) * Self.side
        let top = box.top + (position / columns) * Self.side
        return Picture.Renderer.CPU.Box(left: left, top: top, right: left + Self.side, bottom: top + Self.side).intersection(box)
    }
}

extension Picture.Renderer.CPU.Canvas {
    /// Adds the sprites' light to what is behind with `lighter`, read at each pixel's centre.
    mutating func draw(_ sprites: Picture.Sprites, _ state: Picture.Renderer.CPU.State) {
        guard let inverse = state.inverse else { return }
        let tiles = Picture.Renderer.CPU.Tiles(sprites, state.transform, over: state.reach(in: box))
        let box = self.box
        pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
            state.workers.run(tiles.lists.count) { position in
                let list = tiles.lists[position]
                guard !list.isEmpty else { return }
                let near = Picture.Sprites(list, profile: sprites.profile)
                let tile = tiles.tile(position)
                var y = tile.top
                while y < tile.bottom {
                    var x = tile.left
                    while x < tile.right {
                        let light = near.light(at: Picture.Renderer.CPU.point(inverse, Double(x) + 0.5, Double(y) + 0.5))
                        if light != .transparent {
                            let index = box.index(x, y)
                            let old = unsafe shared[index]
                            unsafe shared[index] = Picture.Renderer.CPU.limited(old, light.composited(over: old, operator: .lighter), state.share(x, y))
                        }
                        x += 1
                    }
                    y += 1
                }
            }
        }
    }
}
