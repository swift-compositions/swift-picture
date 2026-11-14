import IEC_61966
import Picture_PNG_Integration
import Testing

enum `Picture PNG Integration Tests` {}

#if PNG
    extension `Picture PNG Integration Tests` {
        typealias Pixel = Picture.Pixel

        static func pixel(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float) -> Pixel {
            Pixel(color: .init(red: red, green: green, blue: blue), alpha: alpha)
        }

        static func bytes(_ pixel: Pixel) throws(W3C_PNG.Image.Error) -> [UInt8] {
            try W3C_PNG.Image(Raster(width: 1, height: 1, repeating: pixel)).rawPixels.map(\.underlying)
        }
    }

    extension `Picture PNG Integration Tests` {
        @Suite
        struct `A raster of working pixels becomes an 8-bit sRGB image with straight alpha` {}
    }

    extension `Picture PNG Integration Tests`.`A raster of working pixels becomes an 8-bit sRGB image with straight alpha` {
        typealias Tests = `Picture PNG Integration Tests`

        @Test
        func `The image is RGBA at 8 bits, marked sRGB, with the raster's rows top first`() throws {
            let red = Tests.pixel(1, 0, 0, 1)
            let green = Tests.pixel(0, 1, 0, 1)
            let blue = Tests.pixel(0, 0, 1, 1)
            let image = try W3C_PNG.Image(Raster(width: 3, height: 2, pixels: [red, green, blue, blue, .transparent, red]))
            #expect(image.width == 3)
            #expect(image.height == 2)
            #expect(image.colorType == .rgba)
            #expect(image.bitDepth == 8)
            #expect(image.sRGB == .perceptual)
            #expect(image.gamma == .sRGB)
            #expect(image.cicp == nil)
            #expect(image.palette == nil)
            #expect(
                image.rawPixels.map(\.underlying) == [
                    255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
                    0, 0, 255, 255, 0, 0, 0, 0, 255, 0, 0, 255,
                ]
            )
            #expect(try W3C_PNG.parse(W3C_PNG.serialize(image)) == image)
        }

        @Test
        func `Every one of the 256 sRGB levels written as an opaque colour comes back as that level`() throws {
            try (0...255).forEach { (level: Int) throws in
                let color = Picture.Color(red: Float(level) / 255, green: Float(255 - level) / 255, blue: Float(level) / 255)
                #expect(try Tests.bytes(color.pixel) == [UInt8(level), UInt8(255 - level), UInt8(level), 255])
            }
        }

        @Test
        func `Colour is divided by alpha before it is encoded, and alpha is not encoded`() throws {
            #expect(try Tests.bytes(Tests.pixel(0.5, 0.25, 0, 0.5)) == [255, 188, 0, 128])
            #expect(try Tests.bytes(Picture.Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.2).pixel) == [51, 102, 153, 51])
            #expect(try Tests.bytes(Tests.pixel(0.25, 0.25, 0.25, 1)) == [137, 137, 137, 255])
            try (1...255).forEach { (level: Int) throws in
                let color = Picture.Color(red: 1, green: 1, blue: 1, alpha: Float(level) / 255)
                #expect(try Tests.bytes(color.pixel) == [255, 255, 255, UInt8(level)])
            }
        }

        @Test
        func `A pixel with no alpha is transparent black whatever its colour`() throws {
            #expect(try Tests.bytes(.transparent) == [0, 0, 0, 0])
            #expect(try Tests.bytes(Tests.pixel(0.5, 0.5, 0.5, 0)) == [0, 0, 0, 0])
        }

        @Test
        func `A level is the component times 255 rounded to the nearest, halves up`() throws {
            #expect(try Tests.bytes(Tests.pixel(0, 0, 0, 0.5))[3] == 128)
            #expect(try Tests.bytes(Tests.pixel(0, 0, 0, 127.25 / 255))[3] == 127)
            #expect(try Tests.bytes(Tests.pixel(0, 0, 0, 127.75 / 255))[3] == 128)
            #expect(try Tests.bytes(Tests.pixel(0, 0, 0, 0.25 / 255))[3] == 0)
            #expect(try Tests.bytes(Tests.pixel(0, 0, 0, 0.75 / 255))[3] == 1)
            #expect(try Tests.bytes(Tests.pixel(0, 0, 0, 254.75 / 255))[3] == 255)
            #expect(try Tests.bytes(Tests.pixel(0.0001, 0, 0, 1))[0] == 0)
            #expect(try Tests.bytes(Tests.pixel(0.0002, 0, 0, 1))[0] == 1)
        }

        @Test
        func `Components outside zero to one are held to it, and what is not a number is zero`() throws {
            #expect(try Tests.bytes(Tests.pixel(7, -3, 1.0001, 1)) == [255, 0, 255, 255])
            #expect(try Tests.bytes(Tests.pixel(2, 1, 0, 2)) == [255, 188, 0, 255])
            #expect(try Tests.bytes(Tests.pixel(0.5, 0.5, 0.5, -1)) == [0, 0, 0, 0])
            #expect(try Tests.bytes(Tests.pixel(.nan, .infinity, 0.25, 1)) == [0, 255, 137, 255])
            #expect(try Tests.bytes(Tests.pixel(0.25, 0.25, 0.25, .nan))[3] == 0)
        }

        @Test
        func `A raster with no pixels is refused as PNG refuses it`() throws {
            let empty = try Raster<Picture.Pixel>(width: 0, height: 4, pixels: [])
            #expect(throws: W3C_PNG.Image.Error.dimensions) { try W3C_PNG.Image(empty) }
            let flat = try Raster<Picture.Pixel>(width: 4, height: 0, pixels: [])
            #expect(throws: W3C_PNG.Image.Error.dimensions) { try W3C_PNG.Image(flat) }
        }
    }

    extension `Picture PNG Integration Tests` {
        static func image(
            _ colorType: W3C_PNG.ColorType,
            _ bitDepth: Int,
            width: Int,
            height: Int = 1,
            _ bytes: [UInt8],
            palette: [W3C_PNG.PaletteEntry]? = nil,
            cicp: W3C_PNG.CICP? = nil,
            sRGB: W3C_PNG.Intent? = nil,
            gamma: W3C_PNG.Gamma? = nil
        ) throws(W3C_PNG.Image.Error) -> W3C_PNG.Image {
            try W3C_PNG.Image(
                width: width,
                height: height,
                colorType: colorType,
                bitDepth: bitDepth,
                rawPixels: bytes.map { Byte($0) },
                palette: palette,
                cicp: cicp,
                sRGB: sRGB,
                gamma: gamma
            )
        }

        static func linear(_ sample: Int, of maximum: Int) -> Float {
            Float(IEC_61966.SRGB.TransferFunction.linear(Double(sample) / Double(maximum)))
        }

        static func level(_ level: UInt8) -> Float {
            IEC_61966.SRGB.Level.linear(level)
        }

        static func straight(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float) -> Pixel {
            Compositing.Premultiplied(Compositing.Straight(color: .init(red: red, green: green, blue: blue), alpha: alpha))
        }

        static func grey(_ linear: Float) -> Pixel {
            straight(linear, linear, linear, 1)
        }

        static func row(_ pixels: [Pixel]) throws(Raster<Pixel>.Error) -> Raster<Pixel> {
            try Raster(width: Cardinal(UInt(pixels.count)), height: 1, pixels: pixels)
        }
    }

    extension `Picture PNG Integration Tests` {
        @Suite
        struct `A parsed PNG becomes a raster of working pixels` {}
    }

    extension `Picture PNG Integration Tests`.`A parsed PNG becomes a raster of working pixels` {
        typealias Tests = `Picture PNG Integration Tests`

        @Test
        func `A raster whose values 8 bits hold is itself after it is written and read back`() throws {
            let levels = (0...255).map { UInt8($0) }
            let opaque = levels.map { Tests.straight(Tests.level($0), Tests.level(255 - $0), Tests.level($0), 1) }
            let translucent = levels.map {
                Tests.straight(Tests.level(255 - $0), Tests.level(90), Tests.level($0), Float($0) / 255)
            }
            let half = levels.map { Tests.straight(Tests.level($0), Tests.level($0), Tests.level(200), 128 / 255) }
            let clear = levels.map { _ in Tests.Pixel.transparent }
            let raster = try Raster(width: 256, height: 4, pixels: opaque + translucent + half + clear)
            #expect(try Raster(W3C_PNG.Image(raster)) == raster)
            #expect(try Raster(W3C_PNG.parse(W3C_PNG.serialize(W3C_PNG.Image(raster)))) == raster)
        }

        @Test
        func `The raster has the image's width and height, rows top first`() throws {
            let image = try Tests.image(.grayscale, 8, width: 3, height: 2, [0, 51, 102, 153, 204, 255])
            let raster = try Raster(image)
            #expect(raster.width == 3)
            #expect(raster.height == 2)
            #expect(raster.pixels == [0, 51, 102, 153, 204, 255].map { Tests.straight(Tests.level($0), Tests.level($0), Tests.level($0), 1) })
        }

        @Test
        func `Greyscale is read at every depth, each row from its own first byte`() throws {
            let one = try Tests.image(.grayscale, 1, width: 3, height: 2, [0b1010_0000, 0b0100_0000])
            let white = Tests.straight(1, 1, 1, 1)
            let black = Tests.straight(0, 0, 0, 1)
            #expect(try Raster(one).pixels == [white, black, white, black, white, black])
            let two = try Tests.image(.grayscale, 2, width: 4, [0b0001_1011])
            #expect(try Raster(two).pixels == (0...3).map { Tests.grey(Tests.linear($0, of: 3)) })
            let four = try Tests.image(.grayscale, 4, width: 3, [0x07, 0xF0])
            #expect(try Raster(four).pixels == [0, 7, 15].map { Tests.grey(Tests.linear($0, of: 15)) })
            let eight = try Tests.image(.grayscale, 8, width: 2, [37, 255])
            #expect(try Raster(eight) == Tests.row([Tests.straight(Tests.level(37), Tests.level(37), Tests.level(37), 1), white]))
            let sixteen = try Tests.image(.grayscale, 16, width: 2, [0x12, 0x34, 0xFF, 0xFF])
            let grey = Tests.linear(0x1234, of: 65535)
            #expect(try Raster(sixteen) == Tests.row([Tests.straight(grey, grey, grey, 1), white]))
        }

        @Test
        func `Greyscale with alpha is read at 8 and 16 bits, colour multiplied by alpha`() throws {
            let eight = try Tests.image(.grayscaleAlpha, 8, width: 2, [200, 128, 90, 0])
            let grey = Tests.level(200)
            #expect(try Raster(eight) == Tests.row([Tests.straight(grey, grey, grey, Float(128) / 255), .transparent]))
            let sixteen = try Tests.image(.grayscaleAlpha, 16, width: 1, [0x80, 0x01, 0x40, 0x00])
            let deep = Tests.linear(0x8001, of: 65535)
            #expect(try Raster(sixteen) == Tests.row([Tests.straight(deep, deep, deep, Float(Double(0x4000) / 65535))]))
        }

        @Test
        func `Truecolour is read at 8 and 16 bits, opaque`() throws {
            let eight = try Tests.image(.rgb, 8, width: 2, [255, 0, 0, 12, 128, 250])
            #expect(
                try Raster(eight)
                    == Tests.row([Tests.straight(1, 0, 0, 1), Tests.straight(Tests.level(12), Tests.level(128), Tests.level(250), 1)])
            )
            let sixteen = try Tests.image(.rgb, 16, width: 1, [0x00, 0x01, 0x80, 0x00, 0xFF, 0xFE])
            let pixel = Tests.straight(Tests.linear(1, of: 65535), Tests.linear(0x8000, of: 65535), Tests.linear(0xFFFE, of: 65535), 1)
            #expect(try Raster(sixteen) == Tests.row([pixel]))
        }

        @Test
        func `Truecolour with alpha is read at 8 and 16 bits, colour multiplied by alpha`() throws {
            let eight = try Tests.image(.rgba, 8, width: 3, [10, 20, 30, 0, 255, 128, 0, 128, 0, 0, 255, 255])
            #expect(
                try Raster(eight)
                    == Tests.row([
                        .transparent,
                        Tests.straight(1, Tests.level(128), 0, Float(128) / 255),
                        Tests.straight(0, 0, 1, 1),
                    ])
            )
            let sixteen = try Tests.image(.rgba, 16, width: 1, [0xFF, 0xFF, 0x00, 0x00, 0x12, 0x34, 0x80, 0x00])
            let pixel = Tests.straight(1, 0, Tests.linear(0x1234, of: 65535), Float(Double(0x8000) / 65535))
            #expect(try Raster(sixteen) == Tests.row([pixel]))
        }

        @Test
        func `Indexed colour is read at every depth through the palette, opaque`() throws {
            let palette = [
                W3C_PNG.PaletteEntry(r: Byte(255), g: Byte(0), b: Byte(0)),
                W3C_PNG.PaletteEntry(r: Byte(0), g: Byte(128), b: Byte(0)),
                W3C_PNG.PaletteEntry(r: Byte(7), g: Byte(8), b: Byte(9)),
            ]
            let red = Tests.straight(1, 0, 0, 1)
            let green = Tests.straight(0, Tests.level(128), 0, 1)
            let other = Tests.straight(Tests.level(7), Tests.level(8), Tests.level(9), 1)
            let one = try Tests.image(.indexed, 1, width: 3, [0b0100_0000], palette: Array(palette.prefix(2)))
            #expect(try Raster(one) == Tests.row([red, green, red]))
            let two = try Tests.image(.indexed, 2, width: 3, [0b1001_0000], palette: palette)
            #expect(try Raster(two) == Tests.row([other, green, red]))
            let four = try Tests.image(.indexed, 4, width: 3, [0x21, 0x00], palette: palette)
            #expect(try Raster(four) == Tests.row([other, green, red]))
            let eight = try Tests.image(.indexed, 8, width: 3, [1, 2, 0], palette: palette)
            #expect(try Raster(eight) == Tests.row([green, other, red]))
        }

        @Test
        func `An index past the end of the palette is refused`() throws {
            let palette = [W3C_PNG.PaletteEntry(r: Byte(1), g: Byte(2), b: Byte(3))]
            let image = try Tests.image(.indexed, 2, width: 2, [0b0001_0000], palette: palette)
            #expect(throws: Picture.PNG.Error.index) { try Raster(image) }
        }

        @Test
        func `An image whose colour information names another encoding than sRGB is refused`() throws {
            let bytes: [UInt8] = [1, 2, 3]
            #expect(throws: Picture.PNG.Error.encoding) { try Raster(Tests.image(.rgb, 8, width: 1, bytes, cicp: .displayP3)) }
            #expect(throws: Picture.PNG.Error.encoding) {
                try Raster(Tests.image(.rgb, 8, width: 1, bytes, cicp: .init(primaries: 1, transfer: 13, range: .narrow), sRGB: .perceptual))
            }
            #expect(throws: Picture.PNG.Error.encoding) { try Raster(Tests.image(.rgb, 8, width: 1, bytes, gamma: .linear)) }
            let expected = try Tests.row([Tests.straight(Tests.level(1), Tests.level(2), Tests.level(3), 1)])
            #expect(try Raster(Tests.image(.rgb, 8, width: 1, bytes)) == expected)
            #expect(try Raster(Tests.image(.rgb, 8, width: 1, bytes, gamma: .sRGB)) == expected)
            #expect(try Raster(Tests.image(.rgb, 8, width: 1, bytes, sRGB: .relativeColorimetric, gamma: .linear)) == expected)
            #expect(try Raster(Tests.image(.rgb, 8, width: 1, bytes, cicp: .sRGB, gamma: .linear)) == expected)
        }
    }
#endif
