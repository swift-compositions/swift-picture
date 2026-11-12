public import Noise

extension Picture.Effect.Displacement {
    /// A cache of swift-noise for each of a displacement's two noise fields, for reading many points in a row.
    /// It is a value: one for each thread.
    public struct Caches: Sendable {
        public var across: Noise<3, Double>.Cache
        public var down: Noise<3, Double>.Cache

        public init() {
            across = .init()
            down = .init()
        }
    }
}
