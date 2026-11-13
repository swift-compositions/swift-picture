import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A flat camera sees a picture from a focus at a scale` {}
}

extension `Picture Tests`.`A flat camera sees a picture from a focus at a scale` {
    typealias Tests = `Picture Tests`

    static let middle = Tests.at(960, 540)
    static let wide = Picture.Camera(focus: Tests.at(900, 500), center: middle, scale: 1.2)
    static let close = Picture.Camera(focus: Tests.at(1300, 420), center: middle, scale: 4.5)

    @Test
    func `The focus is seen at the centre and the transform is the place of every point`() {
        let camera = Self.close
        #expect(camera.place(of: camera.focus) == Self.middle)
        #expect(camera.transform == Picture.Transform(rows: [[4.5, 0, 960 - 4.5 * 1300], [0, 4.5, 540 - 4.5 * 420]]))
        for point in [Tests.at(0, 0), Tests.at(1300, 420), Tests.at(-12.5, 777)] {
            let moved = camera.transform.applied(to: Vector([point[0], point[1]]))
            #expect(Tests.close(Tests.at(moved[0], moved[1]), camera.place(of: point)))
        }
        #expect(Picture.Camera(center: Self.middle).transform == .identity)
    }

    @Test
    func `A picture seen is a group under the transform`() {
        let picture: Picture = [.fill(Tests.square(10), .solid(.white))]
        #expect(Self.close(picture) == .group(Picture.Group(picture, transform: Self.close.transform)))
    }

    @Test(arguments: [0.0, 0.2, 0.5, 0.9, 1.0])
    func `Between two cameras the scale goes by equal ratios and one point stays where it is`(share: Double) {
        let between = Self.wide.mixed(to: Self.close, at: share)
        #expect(between.scale >= 1.2 - 1e-12 && between.scale <= 4.5 + 1e-12)
        if share == 0.5 { #expect(Tests.close(between.scale * between.scale, 1.2 * 4.5, within: 1e-12)) }
        let ratio = Self.close.scale / Self.wide.scale
        let a = (x: 960 - 1.2 * 900.0, y: 540 - 1.2 * 500.0)
        let b = (x: 960 - 4.5 * 1300.0, y: 540 - 4.5 * 420.0)
        let still = Tests.at((b.x - a.x) / (1.2 - 4.5), (b.y - a.y) / (1.2 - 4.5))
        #expect(ratio > 1)
        #expect(Tests.close(between.place(of: still), Self.wide.place(of: still), within: 1e-7))
        #expect(between.center == Self.middle)
    }

    @Test
    func `The ends of the way are the two cameras, and one scale goes straight`() {
        #expect(Self.wide.mixed(to: Self.close, at: 0) == Self.wide)
        let end = Self.wide.mixed(to: Self.close, at: 1)
        #expect(Tests.close(end.focus, Self.close.focus, within: 1e-9))
        #expect(Tests.close(end.scale, Self.close.scale, within: 1e-12))
        let slid = Picture.Camera(focus: Tests.at(100, 0), center: Self.middle, scale: 2)
        let half = Picture.Camera(focus: Tests.at(0, 0), center: Self.middle, scale: 2).mixed(to: slid, at: 0.25)
        #expect(half.focus == Tests.at(25, 0))
        #expect(half.scale == 2)
        let nearly = Picture.Camera(focus: Tests.at(100, 0), center: Self.middle, scale: 2 * (1 + 1e-13))
        let pushed = Picture.Camera(focus: Tests.at(0, 0), center: Self.middle, scale: 2).mixed(to: nearly, at: 0.25)
        #expect(Tests.close(pushed.focus, Tests.at(25, 0), within: 1e-9))
    }

    @Test
    func `A camera scaled about a point keeps that point's place and multiplies its scale`() {
        let point = Tests.at(700, 300)
        let nearer = Self.wide.scaled(by: 3, about: point)
        #expect(Tests.close(nearer.place(of: point), Self.wide.place(of: point), within: 1e-9))
        #expect(nearer.scale == Self.wide.scale * 3)
        #expect(Self.wide.scaled(by: 0, about: point) == Self.wide)
    }

    @Test
    func `The smear is centred on the frame's still point and grows with the ratio`() throws {
        let smear = try #require(Self.close.smear(since: Self.wide))
        #expect(Tests.close(smear.amount, 1 - 1.2 / 4.5, within: 1e-12))
        let picture = smear.center
        let then = try Self.wide.transform.inverse(of: picture)
        #expect(Tests.close(Self.close.place(of: then), picture, within: 1e-6))
        #expect(Self.close.smear(since: Self.close) == nil)
        #expect(Self.close.smear(since: Picture.Camera(focus: Tests.at(0, 0), center: Self.middle, scale: 0)) == nil)
    }

    @Test
    func `A picture seen since an earlier camera is the earlier view under the smear`() throws {
        let picture: Picture = [.fill(Tests.square(10), .solid(.white))]
        let smear = try #require(Self.close.smear(since: Self.wide))
        #expect(Self.close(picture, since: Self.wide) == .layer(Picture.Layer([Self.wide(picture)], effects: [.zoom(smear)])))
        #expect(Self.close(picture, since: Self.close) == Self.close(picture))
    }
}

extension Picture.Transform {
    fileprivate func inverse(of point: Picture.Plane.Point<2>) throws(Matrix<2, 3, Double>.Error) -> Picture.Plane.Point<2> {
        let moved = try inverted().applied(to: Vector([point[0], point[1]]))
        return Picture.Plane.Point<2>([moved[0], moved[1]])
    }
}
