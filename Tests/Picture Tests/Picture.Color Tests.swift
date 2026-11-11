import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A colour is written in sRGB with straight alpha` {}
}

extension `Picture Tests`.`A colour is written in sRGB with straight alpha` {
    typealias Tests = `Picture Tests`

    @Test
    func `Black, white and clear are the corners`() {
        #expect(Picture.Color.black.pixel == Tests.pixel(0, 0, 0, 1))
        #expect(Picture.Color.white.pixel == Tests.pixel(1, 1, 1, 1))
        #expect(Picture.Color.clear.pixel == .transparent)
        #expect(Picture.Color(gray: 0.5, alpha: 0.25) == Picture.Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.25))
        #expect(Picture.Color(red: 1, green: 0, blue: 0).alpha == 1)
    }

    @Test
    func `Each component goes through the sRGB transfer function and alpha does not`() {
        let color = Picture.Color(red: 0.5, green: 0.04, blue: 1, alpha: 0.5)
        let linear = color.linear
        #expect(Tests.close(linear.color.red, 0.21404114))
        #expect(Tests.close(linear.color.green, 0.04 / 12.92))
        #expect(linear.color.blue == 1)
        #expect(linear.alpha == 0.5)
        #expect(Tests.close(Picture.Color(gray: 0.7353569).linear.color.green, 0.5, within: 1e-5))
    }

    @Test
    func `The pixel is the linear colour multiplied by alpha`() {
        let color = Picture.Color(red: 0.5, green: 0.25, blue: 1, alpha: 0.25)
        let linear = color.linear
        #expect(color.pixel == Tests.pixel(linear.color.red * 0.25, linear.color.green * 0.25, 0.25, 0.25))
        #expect(Picture.Color(red: 1, green: 1, blue: 1, alpha: 0).pixel == .transparent)
        #expect(Picture.Color(red: 1, green: 0, blue: 0, alpha: 0.5).pixel == Tests.pixel(0.5, 0, 0, 0.5))
    }

    @Test
    func `Nothing is clamped`() {
        let bright = Picture.Color(red: 2, green: -0.5, blue: 0, alpha: 1.5)
        #expect(bright.linear.color.red > 4)
        #expect(Tests.close(bright.linear.color.green, -0.5 / 12.92))
        #expect(bright.linear.alpha == 1.5)
        #expect(bright.pixel.alpha == 1.5)
        #expect(bright.pixel.color.red == bright.linear.color.red * 1.5)
    }

    @Test
    func `Colours are equal as written`() {
        #expect(Picture.Color(red: 0.1, green: 0.2, blue: 0.3) == Picture.Color(red: 0.1, green: 0.2, blue: 0.3, alpha: 1))
        #expect(Picture.Color(red: 1, green: 1, blue: 1, alpha: 0) != Picture.Color.clear)
        #expect(Picture.Color(red: 1, green: 1, blue: 1, alpha: 0).pixel == Picture.Color.clear.pixel)
    }
}
