extension Picture.Sprites {
    /// How a sprite's light falls off from its centre to its edge.
    public enum Profile: Sendable, Hashable, CaseIterable {
        /// Full light everywhere inside the radius.
        case hard

        /// Full light at the centre, falling smoothly to none at the radius.
        case soft
    }
}

extension Picture.Sprites.Profile {
    /// The share of a sprite's light at a distance from its centre given in radii.
    public func coverage(at distance: Float) -> Float {
        guard distance < 1 else { return 0 }
        switch self {
        case .hard:
            return 1

        case .soft:
            let rest = 1 - distance * distance
            return rest * rest
        }
    }
}
