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
    /// The light all sprites together add at a point: the sum of each sprite's pixel times its coverage there. A
    /// sprite reaches a point whose squared distance from its centre is below its radius squared, and only there
    /// is the distance itself taken.
    public func light(at point: Picture.Plane.Point<2>) -> Picture.Pixel {
        var total = Picture.Pixel.transparent
        for sprite in sprites {
            let across = point[0] - sprite.center[0]
            let down = point[1] - sprite.center[1]
            let squared = across * across + down * down
            guard sprite.radius > 0, squared < sprite.radius * sprite.radius else { continue }
            let coverage = profile.coverage(at: Float(squared.squareRoot() / sprite.radius))
            total = sprite.color.pixel.composited(over: total, operator: .lighter, coverage: coverage)
        }
        return total
    }

    /// The sprites' light at a point added to one pixel of what is behind: the colours add without a limit,
    /// and alpha, which says how much of what is behind a pixel hides, is held at 1.
    public static func composited(_ light: Picture.Pixel, over backdrop: Picture.Pixel) -> Picture.Pixel {
        let pixel = light.composited(over: backdrop, operator: .lighter)
        guard pixel.alpha > 1 else { return pixel }
        return Picture.Pixel(color: pixel.color, alpha: 1)
    }
}
