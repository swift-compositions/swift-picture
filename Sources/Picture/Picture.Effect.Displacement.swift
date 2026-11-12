public import Noise
import Point
public import Threefry

extension Picture.Effect {
    /// A smooth field of offsets from two noise fields, one for x and one for y, read at the point times
    /// `frequency` and at `phase` along a third axis, and scaled by `amplitude`.
    public struct Displacement: Sendable, Hashable {
        public var seed: Threefry.Key
        public var frequency: Double
        public var amplitude: Double
        public var phase: Double

        public init(seed: Threefry.Key, frequency: Double, amplitude: Double, phase: Double = 0) {
            self.seed = seed
            self.frequency = frequency
            self.amplitude = amplitude
            self.phase = phase
        }
    }
}

extension Picture.Effect.Displacement {
    /// The offset the field gives at a point.
    public func offset(at point: Picture.Plane.Point<2>) -> Vector<2, Double> {
        var caches = Caches()
        return offset(at: point, caches: &caches)
    }

    /// The offset the field gives at a point, read through a cache of swift-noise for each of the two noise
    /// fields: the same offset bit for bit, but reading many points of one lattice cell draws its gradients once.
    public func offset(at point: Picture.Plane.Point<2>, caches: inout Caches) -> Vector<2, Double> {
        let position = Point::Point<3, Double>(x: point[0] * frequency, y: point[1] * frequency, z: phase)
        let across = Noise<3, Double>(seed: seed)
        let down = Noise<3, Double>(seed: Threefry.Key(seed.first, seed.second &+ 1))
        let x = across.value(at: position, cache: &caches.across)
        return Vector([amplitude * x, amplitude * down.value(at: position, cache: &caches.down)])
    }

    /// The point of the sheet read for `point`: the point moved by the field's offset there.
    public func source(of point: Picture.Plane.Point<2>) -> Picture.Plane.Point<2> {
        var caches = Caches()
        return source(of: point, caches: &caches)
    }

    /// `source(of:)` read through caches.
    public func source(of point: Picture.Plane.Point<2>, caches: inout Caches) -> Picture.Plane.Point<2> {
        let offset = offset(at: point, caches: &caches)
        return Picture.Plane.Point<2>([point[0] + offset[0], point[1] + offset[1]])
    }
}
