import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A gradient interpolates working pixels between its stops` {}
}

extension `Picture Tests`.`A gradient interpolates working pixels between its stops` {
    typealias Tests = `Picture Tests`

    static let red = Picture.Color(red: 1, green: 0, blue: 0)
    static let blue = Picture.Color(red: 0, green: 0, blue: 1)

    @Test
    func `Between two stops the pixel is part of the way from one pixel to the other, in linear light`() {
        let gradient = Picture.Gradient([.init(offset: 0, color: .black), .init(offset: 1, color: .white)])
        #expect(gradient.pixel(at: 0.5) == Tests.pixel(0.5, 0.5, 0.5, 1))
        #expect(gradient.pixel(at: 0.25) == Tests.pixel(0.25, 0.25, 0.25, 1))
        let shifted = Picture.Gradient([.init(offset: 0.5, color: Self.red), .init(offset: 1, color: Self.blue)])
        #expect(shifted.pixel(at: 0.625) == Tests.pixel(0.75, 0, 0.25, 1))
    }

    @Test
    func `Alpha is interpolated with the colour, premultiplied`() {
        let gradient = Picture.Gradient([.init(offset: 0, color: Self.red), .init(offset: 1, color: .init(red: 0, green: 0, blue: 1, alpha: 0))])
        #expect(gradient.pixel(at: 0.5) == Tests.pixel(0.5, 0, 0, 0.5))
        #expect(gradient.pixel(at: 0.75) == Tests.pixel(0.25, 0, 0, 0.25))
    }

    @Test
    func `Before the first stop is the first colour and from the last stop on is the last`() {
        let gradient = Picture.Gradient([.init(offset: 0.25, color: Self.red), .init(offset: 0.75, color: Self.blue)])
        #expect(gradient.pixel(at: 0) == Self.red.pixel)
        #expect(gradient.pixel(at: -3) == Self.red.pixel)
        #expect(gradient.pixel(at: 0.25) == Self.red.pixel)
        #expect(gradient.pixel(at: 0.75) == Self.blue.pixel)
        #expect(gradient.pixel(at: 9) == Self.blue.pixel)
        #expect(gradient.pixel(at: .nan) == Self.red.pixel)
    }

    @Test
    func `No stops give transparent and one stop gives its colour everywhere`() {
        #expect(Picture.Gradient([]).pixel(at: 0.5) == .transparent)
        let one = Picture.Gradient([.init(offset: 0.5, color: Self.blue)])
        #expect(one.pixel(at: 0) == Self.blue.pixel)
        #expect(one.pixel(at: 0.5) == Self.blue.pixel)
        #expect(one.pixel(at: 1) == Self.blue.pixel)
    }

    @Test
    func `Two stops at one offset are a hard edge, and an offset below the one before it counts as equal to it`() {
        let edge = Picture.Gradient([
            .init(offset: 0, color: .black), .init(offset: 0.5, color: Self.red), .init(offset: 0.5, color: Self.blue),
            .init(offset: 1, color: .white),
        ])
        #expect(edge.pixel(at: 0.25) == Tests.pixel(0.5, 0, 0, 1))
        #expect(edge.pixel(at: 0.5) == Self.blue.pixel)
        #expect(edge.pixel(at: 0.75) == Tests.pixel(0.5, 0.5, 1, 1))
        let disordered = Picture.Gradient([
            .init(offset: 0, color: .black), .init(offset: 0.5, color: Self.red), .init(offset: 0.25, color: Self.blue),
            .init(offset: 1, color: .white),
        ])
        #expect(disordered.pixel(at: 0.25) == edge.pixel(at: 0.25))
        #expect(disordered.pixel(at: 0.5) == edge.pixel(at: 0.5))
        #expect(disordered.pixel(at: 0.75) == edge.pixel(at: 0.75))
    }
}

extension `Picture Tests` {
    @Suite
    struct `A paint gives a pixel for every point` {}
}

extension `Picture Tests`.`A paint gives a pixel for every point` {
    typealias Tests = `Picture Tests`

    static let ramp = Picture.Gradient([.init(offset: 0, color: .black), .init(offset: 1, color: .white)])

    static func raster(_ pixels: [Picture.Pixel], width: Cardinal, height: Cardinal) throws(Raster<Picture.Pixel>.Error) -> Raster<Picture.Pixel> {
        try Raster(width: width, height: height, pixels: pixels)
    }

    @Test
    func `A solid paint is its colour's pixel everywhere`() {
        let color = Picture.Color(red: 0.5, green: 0.25, blue: 1, alpha: 0.5)
        #expect(Picture.Paint.solid(color).pixel(at: Tests.at(0, 0)) == color.pixel)
        #expect(Picture.Paint.solid(color).pixel(at: Tests.at(-1e9, 42)) == color.pixel)
    }

    @Test
    func `A linear gradient's parameter is how far along the line the point's foot lies`() {
        let linear = Picture.Paint.Linear(from: Tests.at(10, 20), to: Tests.at(30, 20), Self.ramp)
        #expect(linear.parameter(at: Tests.at(10, 20)) == 0)
        #expect(linear.parameter(at: Tests.at(30, 20)) == 1)
        #expect(linear.parameter(at: Tests.at(20, 99)) == 0.5)
        #expect(linear.parameter(at: Tests.at(0, -5)) == -0.5)
        #expect(linear.parameter(at: Tests.at(50, 0)) == 2)
        let slanted = Picture.Paint.Linear(from: Tests.at(0, 0), to: Tests.at(3, 4), Self.ramp)
        #expect(Tests.close(slanted.parameter(at: Tests.at(3, 4)), 1))
        #expect(Tests.close(slanted.parameter(at: Tests.at(-4, 3)), 0))
        #expect(Tests.close(slanted.parameter(at: Tests.at(1.5 + 4, 2 - 3)), 0.5))
        #expect(Picture.Paint.linear(linear).pixel(at: Tests.at(20, 99)) == Tests.pixel(0.5, 0.5, 0.5, 1))
    }

    @Test
    func `A line with no length gives parameter zero everywhere`() {
        let point = Picture.Paint.Linear(from: Tests.at(5, 5), to: Tests.at(5, 5), Self.ramp)
        #expect(point.parameter(at: Tests.at(5, 5)) == 0)
        #expect(point.parameter(at: Tests.at(100, -100)) == 0)
    }

    @Test
    func `A radial gradient's parameter is the distance from the centre in radii`() {
        let radial = Picture.Paint.Radial(center: Tests.at(10, 10), radius: 10, Self.ramp)
        #expect(radial.parameter(at: Tests.at(10, 10)) == 0)
        #expect(radial.parameter(at: Tests.at(13, 14)) == 0.5)
        #expect(radial.parameter(at: Tests.at(10, 0)) == 1)
        #expect(radial.parameter(at: Tests.at(40, 10)) == 3)
        #expect(Picture.Paint.radial(radial).pixel(at: Tests.at(13, 14)) == Tests.pixel(0.5, 0.5, 0.5, 1))
        #expect(Picture.Paint.Radial(center: Tests.at(0, 0), radius: 0, Self.ramp).parameter(at: Tests.at(3, 4)) == 0)
        #expect(Picture.Paint.Radial(center: Tests.at(0, 0), radius: -2, Self.ramp).parameter(at: Tests.at(3, 4)) == 0)
    }

    @Test
    func `An image lies with its first pixel's corner at the origin, one pixel to a unit`() throws {
        let red = Tests.pixel(1, 0, 0, 1)
        let blue = Tests.pixel(0, 0, 1, 1)
        let green = Tests.pixel(0, 1, 0, 1)
        let white = Tests.pixel(1, 1, 1, 1)
        let image = Picture.Image(try Self.raster([red, blue, green, white], width: 2, height: 2))
        #expect(image.placement == .identity)
        #expect(image.sampling == .bilinear)
        #expect(image.edge == .constant(.transparent))
        #expect(image.pixel(at: Tests.at(0.5, 0.5)) == red)
        #expect(image.pixel(at: Tests.at(1.5, 0.5)) == blue)
        #expect(image.pixel(at: Tests.at(0.5, 1.5)) == green)
        #expect(image.pixel(at: Tests.at(1.5, 1.5)) == white)
        #expect(image.pixel(at: Tests.at(1, 0.5)) == Tests.pixel(0.5, 0, 0.5, 1))
        #expect(image.pixel(at: Tests.at(0.5, 1)) == Tests.pixel(0.5, 0.5, 0, 1))
        #expect(Picture.Paint.image(image).pixel(at: Tests.at(1.5, 0.5)) == blue)
    }

    @Test
    func `Sampling and the edge are the image's own`() throws {
        let red = Tests.pixel(1, 0, 0, 1)
        let blue = Tests.pixel(0, 0, 1, 1)
        let raster = try Self.raster([red, blue], width: 2, height: 1)
        let nearest = Picture.Image(raster, sampling: .nearest)
        #expect(nearest.pixel(at: Tests.at(0.99, 0.5)) == red)
        #expect(nearest.pixel(at: Tests.at(1.01, 0.5)) == blue)
        #expect(nearest.pixel(at: Tests.at(5, 0.5)) == .transparent)
        #expect(nearest.pixel(at: Tests.at(0.5, -1)) == .transparent)
        #expect(Picture.Image(raster, sampling: .nearest, edge: .extend).pixel(at: Tests.at(5, 7)) == blue)
        #expect(Picture.Image(raster, sampling: .nearest, edge: .wrap).pixel(at: Tests.at(2.5, 0.5)) == red)
        #expect(Picture.Image(raster).pixel(at: Tests.at(0, 0.5)) == Tests.pixel(0.5, 0, 0, 0.5))
    }

    @Test
    func `The placement moves the image as a group's transform moves its content`() throws {
        let red = Tests.pixel(1, 0, 0, 1)
        let blue = Tests.pixel(0, 0, 1, 1)
        let raster = try Self.raster([red, blue], width: 2, height: 1)
        let moved = Picture.Image(raster, placement: .translation(Vector([10, 20])), sampling: .nearest)
        #expect(moved.pixel(at: Tests.at(10.5, 20.5)) == red)
        #expect(moved.pixel(at: Tests.at(11.5, 20.5)) == blue)
        #expect(moved.pixel(at: Tests.at(0.5, 0.5)) == .transparent)
        let doubled = Picture.Image(raster, placement: .init(rows: [[2, 0, 0], [0, 3, 0]]), sampling: .nearest)
        #expect(doubled.pixel(at: Tests.at(1.9, 2.9)) == red)
        #expect(doubled.pixel(at: Tests.at(2.1, 0.1)) == blue)
        #expect(doubled.pixel(at: Tests.at(1, 3.1)) == .transparent)
    }

    @Test
    func `An image squashed to no area, and an image with no pixels, paint nothing`() throws {
        let raster = try Self.raster([Tests.pixel(1, 0, 0, 1)], width: 1, height: 1)
        let flat = Picture.Image(raster, placement: .init(rows: [[1, 0, 0], [0, 0, 0]]), edge: .extend)
        #expect(flat.pixel(at: Tests.at(0.5, 0)) == .transparent)
        let empty = try Self.raster([], width: 0, height: 3)
        #expect(Picture.Image(empty, edge: .extend).pixel(at: Tests.at(0.5, 0.5)) == .transparent)
        #expect(Picture.Image(empty, edge: .constant(Tests.pixel(0, 1, 0, 1))).pixel(at: Tests.at(0.5, 0.5)) == Tests.pixel(0, 1, 0, 1))
        #expect(Picture.Image(raster, edge: .extend).pixel(at: Tests.at(.infinity, 0)) == .transparent)
    }
}
