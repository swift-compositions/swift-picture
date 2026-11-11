import Picture_PNG_Integration
import Testing

enum `Picture PNG Integration Tests` {}

extension `Picture PNG Integration Tests` {
    typealias Pixel = Picture.Pixel

    static func pixel(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float) -> Pixel {
        Pixel(color: .init(red: red, green: green, blue: blue), alpha: alpha)
    }

    static func bytes(_ pixels: [Pixel], width: Cardinal, height: Cardinal) throws -> [UInt8] {
        try W3C_PNG.Image(Raster(width: width, height: height, pixels: pixels)).rawPixels.map(\.underlying)
    }

    static func bytes(_ pixel: Pixel) throws -> [UInt8] {
        try bytes([pixel], width: 1, height: 1)
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
