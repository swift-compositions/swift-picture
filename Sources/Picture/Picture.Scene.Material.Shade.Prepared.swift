import Numeric
import Vector

extension Picture.Scene.Material.Shade {
    /// A shade with what depends on it alone worked out once, for reading it at many points: the lamp's length
    /// and the rim's power. `light(facing:)` turns the normal to face the eye once for both terms; each term is
    /// the shade's own, step for step, and the shade's `light(facing:)` goes through it.
    package struct Prepared: Sendable {
        let toward: Vector<3, Double>
        let reach: Double
        let rim: Double
        let power: Double
    }
}

extension Picture.Scene.Material.Shade.Prepared {
    package init(_ shade: Picture.Scene.Material.Shade) {
        let toward = shade.toward
        self.init(
            toward: toward,
            reach: toward.length,
            rim: shade.rim,
            power: Swift.max(shade.sharpness, 0)
        )
    }

    /// `Picture.Scene.Material.Shade.light(facing:)`: `cosine(facing:)` plus `rim(facing:)`.
    package func light(facing normal: Vector<3, Double>) -> Double {
        guard let n = Picture.Scene.Material.Shade.facing(normal) else { return 0 + 0 }
        let cosine = reach > 0 && reach.isFinite ? Swift.max((n.0 * toward[0] + n.1 * toward[1] + n.2 * toward[2]) / reach, 0) : 0
        let edge = 1 - Swift.min(Swift.max(n.2, 0), 1)
        let falloff = edge > 0 ? Double.math.pow(edge, power) : (power == 0 ? 1 : 0)
        return cosine + rim * falloff
    }
}
