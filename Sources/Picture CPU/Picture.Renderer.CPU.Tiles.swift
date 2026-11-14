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
            let lit = Lit(x: sprite.center[0], y: sprite.center[1], radius: sprite.radius, pixel: sprite.color.pixel)
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
            let distance = (across * across + down * down).squareRoot()
            guard distance < sprite.radius else { continue }
            let coverage = profile.coverage(at: Float(distance / sprite.radius))
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

extension Picture.Renderer.CPU.Canvas {
    /// Adds the sprites' light to what is behind, read at each pixel's centre, by `Picture.Sprites.composited(_:over:)`.
    mutating func draw(_ sprites: Picture.Sprites, _ state: Picture.Renderer.CPU.State) {
        guard let inverse = state.inverse else { return }
        let tiles = Picture.Renderer.CPU.Tiles(sprites, state.transform, over: state.reach(in: box))
        let map = Picture.Renderer.CPU.Affine(inverse)
        let profile = sprites.profile
        let box = self.box
        unsafe Picture.Renderer.CPU.Mask.reading(state.mask) { clip in
            pixels.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                let shared = unsafe Picture.Renderer.CPU.Workers.Pixels(base: base)
                state.workers.run(tiles.lists.count) { position in
                    tiles.lists[position].withUnsafeBufferPointer { list in
                        guard !list.isEmpty else { return }
                        let tile = tiles.tile(position)
                        var y = tile.top
                        while y < tile.bottom {
                            let shares = unsafe clip.row(y)
                            let centre = Double(y) + 0.5
                            var x = tile.left
                            while x < tile.right {
                                let across = Double(x) + 0.5
                                let light = unsafe Picture.Renderer.CPU.Tiles.light(list, profile, at: map.x(across, centre), map.y(across, centre))
                                if light != .transparent {
                                    let index = box.index(x, y)
                                    let old = unsafe shared[index]
                                    unsafe shared[index] = Picture.Renderer.CPU.limited(old, Picture.Sprites.composited(light, over: old), unsafe shares.share(x))
                                }
                                x += 1
                            }
                            y += 1
                        }
                    }
                }
            }
        }
    }
}
