import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `A renderer draws a mean of pictures as the mean of their sheets` {}
}

extension `Picture CPU Tests`.`A renderer draws a mean of pictures as the mean of their sheets` {
    typealias Tests = `Picture CPU Tests`

    static let backdrop = Tests.pixel(0.2, 0.4, 0.6, 1)

    @Test
    func `Each pixel is the mean of the pictures' pixels there, put over what is behind`() throws {
        let pictures: [Picture] = [
            [Tests.fill(Tests.rectangle(0, 0, 3, 1), Tests.red)],
            [Tests.fill(Tests.rectangle(1, 0, 3, 1), Tests.blue)],
            [Tests.fill(Tests.rectangle(2, 0, 3, 1), Tests.translucent)],
            [],
        ]
        let sheets = try pictures.map { try Tests.drawn($0, on: Tests.canvas(6, 1)) }
        let raster = try Tests.drawn(Picture.mean(of: pictures), on: Tests.canvas(6, 1, Self.backdrop))
        for (x, drawn) in raster.pixels.enumerated() {
            var mean = Tests.pixel(0, 0, 0, 0)
            for sheet in sheets {
                let pixel = sheet.pixels[x]
                mean = Tests.pixel(
                    mean.color.red + pixel.color.red / 4,
                    mean.color.green + pixel.color.green / 4,
                    mean.color.blue + pixel.color.blue / 4,
                    mean.alpha + pixel.alpha / 4
                )
            }
            #expect(Tests.close(drawn, Picture.Layer([]).composited(mean, over: Self.backdrop)))
        }
        #expect(raster.pixels[5] == Self.backdrop)
    }

    @Test
    func `The mean of a picture with itself is that picture`() throws {
        let picture: Picture = [
            Tests.fill(Tests.polygon([Tests.at(0.3, 0.2), Tests.at(7.6, 1.1), Tests.at(1.2, 5.8)]), Tests.translucent),
            Tests.fill(Tests.rectangle(2, 1, 3, 3), Tests.blue),
        ]
        let backdrop = Tests.canvas(8, 6, Self.backdrop)
        for count in [2, 3, 8] {
            let mean = Picture.mean(of: Array(repeating: picture, count: count))
            #expect(Tests.close(try Tests.drawn(mean, on: backdrop), try Tests.drawn(picture, on: backdrop)))
        }
    }

    @Test
    func `A square that moves its own width while the shutter is open is smeared over twice its width`() throws {
        // The square starts over pixels 2 to 5 and ends over 6 to 9: a point is covered for the share of the
        // exposure the square spends over it, rising for four pixels and falling for four.
        let exposure = Picture.exposure(samples: 64) { fraction in
            [Tests.fill(Tests.rectangle(2 + 4 * fraction, 0, 4, 1), Tests.red)]
        }
        let raster = try Tests.drawn(exposure, on: Tests.canvas(12, 1))
        let expected: [Float] = [0, 0, 0.125, 0.375, 0.625, 0.875, 0.875, 0.625, 0.375, 0.125, 0, 0]
        for (pixel, share) in zip(raster.pixels, expected) {
            #expect(Tests.close(pixel, Tests.pixel(share, 0, 0, share), within: 1e-4))
        }
        #expect(abs(raster.pixels.reduce(0) { $0 + $1.alpha } - 4) < 1e-4)
    }

    @Test
    func `What stands still under an exposure is drawn as it is`() throws {
        let still = Tests.fill(Tests.rectangle(0.5, 0.25, 3, 1.5), Tests.blue)
        let exposure = Picture.exposure(samples: 6) { fraction in
            [still, Tests.fill(Tests.rectangle(5 + fraction, 0, 1, 1), Tests.red)]
        }
        let raster = try Tests.drawn(exposure, on: Tests.canvas(8, 2, Self.backdrop))
        let alone = try Tests.drawn([still], on: Tests.canvas(8, 2, Self.backdrop))
        for (x, y) in Tests.positions(5, 2) {
            #expect(Tests.close(Tests.at(raster, x, y), Tests.at(alone, x, y)))
        }
    }
}
