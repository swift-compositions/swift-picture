extension Picture {
    /// Round sprites that all add their light: thousands of particles as one element.
    public struct Sprites: Sendable, Hashable {
        public var sprites: [Sprite]
        public var profile: Profile

        public init(_ sprites: [Sprite], profile: Profile = .soft) {
            self.sprites = sprites
            self.profile = profile
        }
    }
}

extension Picture.Sprites {
    /// The light all sprites together add at a point: the sum of each sprite's pixel times its coverage there.
    public func light(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        var total = Picture.Pixel.transparent
        for sprite in sprites {
            let across = point[0] - sprite.center[0]
            let down = point[1] - sprite.center[1]
            let distance = (across * across + down * down).squareRoot()
            guard distance < sprite.radius else { continue }
            let coverage = profile.coverage(at: Float(distance / sprite.radius))
            total = sprite.color.pixel.composited(over: total, operator: .lighter, coverage: coverage)
        }
        return total
    }
}
