import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer puts a fill's paint over what is behind by the share it covers` {}
}

extension `Picture CPU Tests`.`A renderer puts a fill's paint over what is behind by the share it covers` {
    typealias Tests = `Picture CPU Tests`

    @Test
    func `Each pixel takes the paint over what was there, with the covered share of its square as coverage`() throws {
        let backdrop = Tests.blue.pixel
        let raster = try Tests.drawn([Tests.fill(Tests.rectangle(1, 0, 1.5, 2), Tests.translucent)], on: Tests.canvas(4, 2, backdrop))
        let paint = Tests.translucent.pixel
        for y: UInt in [0, 1] {
            #expect(Tests.at(raster, 0, y) == backdrop)
            #expect(Tests.at(raster, 1, y) == paint.composited(over: backdrop, coverage: 1))
            #expect(Tests.at(raster, 2, y) == paint.composited(over: backdrop, coverage: 0.5))
            #expect(Tests.at(raster, 3, y) == backdrop)
        }
    }

    @Test
    func `The fill covers what its rule calls inside`() throws {
        let outer = Tests.rectangle(0, 0, 3, 1)
        let inner = Tests.rectangle(1, 0, 1, 1)
        let both = Picture.Plane.Path(subpaths: outer.subpaths + inner.subpaths)
        let nonzero = try Tests.drawn([Tests.fill(both, Tests.red)], on: Tests.canvas(3, 1))
        let evenodd = try Tests.drawn([Tests.fill(both, Tests.red, rule: .evenodd)], on: Tests.canvas(3, 1))
        #expect(nonzero.pixels == [Tests.red.pixel, Tests.red.pixel, Tests.red.pixel])
        #expect(evenodd.pixels == [Tests.red.pixel, .transparent, Tests.red.pixel])
    }

    @Test
    func `A paint is read at each pixel's centre in the shape's own space`() throws {
        let gradient = Picture.Gradient([.init(offset: 0, color: Tests.red), .init(offset: 1, color: Tests.translucent)])
        let linear = Picture.Paint.linear(.init(from: Tests.at(0, 0), to: Tests.at(4, 1), gradient))
        let radial = Picture.Paint.radial(.init(center: Tests.at(1, 1), radius: 3, gradient))
        let scale = Picture.Transform(rows: [[2, 0, 1], [0, 2, 0]])
        for paint in [linear, radial] {
            let shape = Picture.Element.shape(.init(Tests.rectangle(0, 0, 4, 2), fill: .init(paint)))
            let plain = try Tests.drawn([shape], on: Tests.canvas(4, 2))
            let scaled = try Tests.drawn([.group(.init([shape], transform: scale))], on: Tests.canvas(9, 4))
            for y: UInt in 0..<2 {
                for x: UInt in 0..<4 {
                    #expect(Tests.at(plain, x, y) == paint.pixel(at: Tests.at(Double(x) + 0.5, Double(y) + 0.5)))
                }
            }
            for y: UInt in 0..<4 {
                for x: UInt in 1..<9 {
                    let inner = Tests.at((Double(x) + 0.5 - 1) / 2, (Double(y) + 0.5) / 2)
                    #expect(Tests.close(Tests.at(scaled, x, y), paint.pixel(at: inner)))
                }
            }
        }
    }

    @Test
    func `An image paint is the image's pixel at each centre`() throws {
        let image = Picture.Image(
            Tests.Canvas(width: 2, height: 1, repeating: Tests.red.pixel).replacingFirst(with: Tests.translucent.pixel),
            placement: .init(rows: [[2, 0, 0], [0, 2, 0]])
        )
        let raster = try Tests.drawn([.shape(.init(Tests.rectangle(0, 0, 4, 2), fill: .init(.image(image))))], on: Tests.canvas(4, 2))
        for y: UInt in 0..<2 {
            for x: UInt in 0..<4 {
                #expect(Tests.at(raster, x, y) == image.pixel(at: Tests.at(Double(x) + 0.5, Double(y) + 0.5)))
            }
        }
    }

    @Test
    func `What lies off the raster is not drawn, and a larger raster shows the same pixels`() throws {
        let picture: Picture = [
            Tests.fill(Tests.polygon([Tests.at(-3, -1), Tests.at(7.3, 0.4), Tests.at(2.2, 9.5)]), Tests.translucent),
            .group(.init([Tests.fill(Tests.rectangle(-2, -2, 20, 20), Tests.red)], clip: .init(Tests.rectangle(1.5, 0.25, 2, 2.5)))),
            .layer(.init([Tests.fill(Tests.rectangle(2.5, 1.5, 3, 3), Tests.blue)], opacity: 0.5, blend: .multiply)),
        ]
        let small = try Tests.drawn(picture, on: Tests.canvas(5, 3))
        let large = try Tests.drawn(picture, on: Tests.canvas(12, 11))
        let window = try large.cropped(to: .init(x: .zero, y: .zero, width: 5, height: 3))
        #expect(Tests.close(small, window))
    }
}

extension Raster<Picture.Pixel> {
    /// The raster with its first pixel replaced.
    func replacingFirst(with pixel: Picture.Pixel) -> Self {
        var copy = self
        copy[x: .zero, y: .zero] = pixel
        return copy
    }
}
