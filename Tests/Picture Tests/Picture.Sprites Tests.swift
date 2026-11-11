import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `Sprites add their light` {}
}

extension `Picture Tests`.`Sprites add their light` {
    typealias Tests = `Picture Tests`

    static let red = Picture.Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let blue = Picture.Color(red: 0, green: 0, blue: 1)

    @Test
    func `A hard sprite is full inside its radius and a soft one falls off as the square of one minus the distance squared`() {
        typealias Profile = Picture.Sprites.Profile
        #expect(Profile.hard.coverage(at: 0) == 1)
        #expect(Profile.hard.coverage(at: 0.999) == 1)
        #expect(Profile.hard.coverage(at: 1) == 0)
        #expect(Profile.hard.coverage(at: 2) == 0)
        #expect(Profile.soft.coverage(at: 0) == 1)
        #expect(Profile.soft.coverage(at: 0.5) == 0.5625)
        #expect(Profile.soft.coverage(at: 0.25) == 0.87890625)
        #expect(Profile.soft.coverage(at: 1) == 0)
        #expect(Profile.soft.coverage(at: 3) == 0)
        #expect(Profile.soft.coverage(at: .nan) == 0)
        #expect(Profile.allCases == [.hard, .soft])
    }

    @Test
    func `One sprite gives its pixel times its coverage, and nothing outside its radius`() {
        let hard = Picture.Sprites([.init(center: Tests.at(10, 10), radius: 4, color: Self.red)], profile: .hard)
        #expect(hard.light(at: Tests.at(10, 10)) == Tests.pixel(0.5, 0, 0, 0.5))
        #expect(hard.light(at: Tests.at(13.9, 10)) == Tests.pixel(0.5, 0, 0, 0.5))
        #expect(hard.light(at: Tests.at(14, 10)) == .transparent)
        #expect(hard.light(at: Tests.at(10, 20)) == .transparent)
        let soft = Picture.Sprites([.init(center: Tests.at(10, 10), radius: 4, color: Self.red)])
        #expect(soft.profile == .soft)
        #expect(soft.light(at: Tests.at(10, 10)) == Tests.pixel(0.5, 0, 0, 0.5))
        #expect(soft.light(at: Tests.at(12, 10)) == Tests.pixel(0.28125, 0, 0, 0.28125))
        #expect(soft.light(at: Tests.at(10, 8)) == Tests.pixel(0.28125, 0, 0, 0.28125))
    }

    @Test
    func `Sprites that overlap add up, past one, in any order`() {
        let first = Picture.Sprites.Sprite(center: Tests.at(0, 0), radius: 4, color: Self.red)
        let second = Picture.Sprites.Sprite(center: Tests.at(2, 0), radius: 4, color: Self.blue)
        let third = Picture.Sprites.Sprite(center: Tests.at(1, 0), radius: 8, color: .white)
        let sprites = Picture.Sprites([first, second, third], profile: .hard)
        #expect(sprites.light(at: Tests.at(1, 0)) == Tests.pixel(1.5, 1, 2, 2.5))
        #expect(Picture.Sprites([third, second, first], profile: .hard).light(at: Tests.at(1, 0)) == Tests.pixel(1.5, 1, 2, 2.5))
        #expect(sprites.light(at: Tests.at(-3, 0)) == Tests.pixel(1.5, 1, 1, 1.5))
        #expect(Picture.Sprites([first, first], profile: .hard).light(at: Tests.at(0, 0)) == Tests.pixel(1, 0, 0, 1))
    }

    @Test
    func `No sprites, and a sprite with no radius, give no light`() {
        #expect(Picture.Sprites([]).light(at: Tests.at(0, 0)) == .transparent)
        let point = Picture.Sprites([.init(center: Tests.at(0, 0), radius: 0, color: Self.blue)], profile: .hard)
        #expect(point.light(at: Tests.at(0, 0)) == .transparent)
        let negative = Picture.Sprites([.init(center: Tests.at(0, 0), radius: -3, color: Self.blue)], profile: .hard)
        #expect(negative.light(at: Tests.at(0, 0)) == .transparent)
    }
}
