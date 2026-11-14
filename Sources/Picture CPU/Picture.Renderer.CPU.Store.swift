import Picture
import Synchronization

extension Picture.Renderer.CPU {
    /// The rasters a renderer has drawn for images that name their picture, kept from one picture to the next
    /// and shared by every thread that draws through the renderer. It holds at most `bound` pixels; past that
    /// the rasters asked for longest ago go first, and a raster larger than the bound is not kept at all.
    final class Store: Sendable {
        let bound: Int
        let kept: Mutex<(rasters: [Key: (raster: Raster<Picture.Pixel>, used: UInt64)], pixels: Int, clock: UInt64)>

        init(bound: Int) {
            self.bound = bound
            self.kept = Mutex((rasters: [:], pixels: 0, clock: 0))
        }
    }
}

extension Picture.Renderer.CPU.Store {
    /// The raster kept for a source, which is thereby the one asked for last.
    func raster(for key: Key) -> Raster<Picture.Pixel>? {
        kept.withLock { kept in
            guard let raster = kept.rasters[key]?.raster else { return nil }
            kept.clock += 1
            kept.rasters[key] = (raster, kept.clock)
            return raster
        }
    }

    /// Keeps a raster for a source, and lets go of those asked for longest ago until the bound holds.
    func keep(_ raster: Raster<Picture.Pixel>, for key: Key) {
        let size = raster.pixels.count
        guard size <= bound else { return }
        kept.withLock { kept in
            guard kept.rasters[key] == nil else { return }
            kept.clock += 1
            kept.rasters[key] = (raster, kept.clock)
            kept.pixels += size
            while kept.pixels > bound, let oldest = kept.rasters.min(by: { $0.value.used < $1.value.used }) {
                kept.pixels -= oldest.value.raster.pixels.count
                kept.rasters[oldest.key] = nil
            }
        }
    }

    /// A picture with every image that names its picture given its pixels: each distinct source is taken
    /// from the store or drawn, the ones to draw side by side on the workers, and what is drawn is kept.
    /// A source is drawn exactly as `Picture.Image.Source.raster(through:)` draws it through this renderer,
    /// and a source inside the pictures a source's drawing names is drawn the same way first. Each raster is kept as soon as it is drawn and
    /// the store is asked again just before a source is drawn. The sources are drawn in rounds: a source waits
    /// until every other source of the picture that its own pictures name, however deep, is drawn and kept, so
    /// a source that another source also names is drawn once, and before the one that names it.
    func resolved(_ picture: Picture, _ workers: Picture.Renderer.CPU.Workers) throws(Picture.Renderer.Error) -> Picture {
        var places: [Key: Int] = [:]
        var keys: [Key] = []
        var order: [Int] = []
        Picture.Renderer.CPU.images(of: picture) { image in
            guard case .drawing(let source) = image.content else { return }
            let key = Key(source)
            if let place = places[key] {
                order.append(place)
            } else {
                places[key] = keys.count
                order.append(keys.count)
                keys.append(key)
            }
        }
        guard !keys.isEmpty else { return picture }
        var rasters = keys.map { raster(for: $0) }
        var missing = keys.indices.filter { rasters[$0] == nil }
        let inside: [Int: Set<Key>] = Dictionary(
            uniqueKeysWithValues: missing.map { place in
                var named = Set<Key>()
                for picture in keys[place].source.pictures {
                    Self.sources(of: picture, into: &named)
                }
                return (place, named)
            }
        )
        while !missing.isEmpty {
            let waiting = Set(missing.map { keys[$0] })
            var ready = missing.filter { inside[$0, default: []].isDisjoint(with: waiting) }
            if ready.isEmpty { ready = missing }
            let renderer = Picture.Renderer.cpu(Picture.Renderer.CPU.Workers(count: Swift.max(1, workers.count / ready.count)), self)
            let drawn = Mutex([Result<Raster<Picture.Pixel>, Picture.Renderer.Error>?](repeating: nil, count: ready.count))
            workers.run(ready.count) { part in
                let key = keys[ready[part]]
                let result: Result<Raster<Picture.Pixel>, Picture.Renderer.Error>
                if let kept = raster(for: key) {
                    result = .success(kept)
                } else {
                    do throws(Picture.Renderer.Error) {
                        let raster = try key.source.raster(through: renderer)
                        keep(raster, for: key)
                        result = .success(raster)
                    } catch {
                        result = .failure(error)
                    }
                }
                drawn.withLock { $0[part] = result }
            }
            for (place, result) in zip(ready, drawn.withLock { $0 }) {
                guard let result else { throw .unsupported }
                rasters[place] = try result.get()
            }
            let done = Set(ready)
            missing.removeAll { done.contains($0) }
        }
        var next = 0
        return Picture.Renderer.CPU.mapped(picture) { image in
            guard case .drawing = image.content else { return image }
            var drawn = image
            drawn.content = .pixels(rasters[order[next]] ?? Raster(width: .zero, height: .zero, repeating: .transparent))
            next += 1
            return drawn
        }
    }
}

extension Picture.Renderer.CPU.Store {
    /// Adds the source of every image a picture paints with to a set, and the sources their drawings' pictures
    /// name, as deep as they go.
    static func sources(of picture: Picture, into named: inout Set<Key>) {
        var found: [Picture.Image.Source] = []
        Picture.Renderer.CPU.images(of: picture) { image in
            if case .drawing(let source) = image.content { found.append(source) }
        }
        for source in found where named.insert(Key(source)).inserted {
            for inner in source.pictures {
                sources(of: inner, into: &named)
            }
        }
    }
}

extension Picture.Renderer.CPU {
    /// Calls `body` with every image a picture paints with, in the order `mapped(_:_:)` meets them: an
    /// element's fill before its stroke, and a group's or a layer's content where the group or layer stands.
    /// The picture an image names as its source is not looked into.
    static func images(of picture: Picture, _ body: (Picture.Image) -> Void) {
        for element in picture.elements {
            switch element {
            case .shape(let shape):
                if case .image(let image) = shape.fill?.paint { body(image) }
                if case .image(let image) = shape.stroke?.paint { body(image) }

            case .group(let group): images(of: group.content, body)

            case .layer(let layer): images(of: layer.content, body)

            case .sprites, .scene, .pane: break
            }
        }
    }

    /// A picture with every image it paints with replaced by what `change` makes of it, in the order
    /// `images(of:_:)` meets them.
    static func mapped(_ picture: Picture, _ change: (Picture.Image) -> Picture.Image) -> Picture {
        Picture(
            picture.elements.map { element in
                switch element {
                case .shape(var shape):
                    if case .image(let image) = shape.fill?.paint { shape.fill?.paint = .image(change(image)) }
                    if case .image(let image) = shape.stroke?.paint { shape.stroke?.paint = .image(change(image)) }
                    return .shape(shape)

                case .group(var group):
                    group.content = mapped(group.content, change)
                    return .group(group)

                case .layer(var layer):
                    layer.content = mapped(layer.content, change)
                    return .layer(layer)

                case .sprites, .scene, .pane:
                    return element
                }
            }
        )
    }
}
