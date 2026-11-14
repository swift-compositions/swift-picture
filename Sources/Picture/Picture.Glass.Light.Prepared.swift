import Numeric
import Vector

extension Picture.Glass.Light {
    /// A light with what depends on it alone worked out once, for reading it at many points: the halfway
    /// direction, the light's length across the view and its parameters held to their ranges. Each reading is
    /// the light's own, step for step, and the light's public readings go through it.
    struct Prepared: Sendable {
        let light: Picture.Glass.Light

        /// The halfway direction between the light and the eye and its length, where the light has a direction.
        let half: (Double, Double, Double)
        let size: Double
        let shines: Bool

        let strength: Double
        let gloss: Double
        let power: Double
        let sheen: Double

        /// The light's length across the view, the counter-side's share and the focus, for the side's share.
        let across: Double
        let counter: Double
        let focus: Double
    }
}

extension Picture.Glass.Light.Prepared {
    init(_ light: Picture.Glass.Light) {
        let direction = light.direction
        var half = (direction[0], direction[1], direction[2])
        let reach = (half.0 * half.0 + half.1 * half.1 + half.2 * half.2).squareRoot()
        var size = 0.0
        let shines = reach > 0 && reach.isFinite
        if shines {
            half = (half.0 / reach, half.1 / reach, half.2 / reach + 1)
            size = (half.0 * half.0 + half.1 * half.1 + half.2 * half.2).squareRoot()
        }
        self.init(
            light: light,
            half: half,
            size: size,
            shines: shines,
            strength: Swift.min(Swift.max(light.highlight, 0), 1),
            gloss: Swift.max(light.gloss, 0),
            power: Swift.max(light.sharpness, 0),
            sheen: Swift.min(Swift.max(light.sheen, 0), 1),
            across: (direction[0] * direction[0] + direction[1] * direction[1]).squareRoot(),
            counter: Swift.min(Swift.max(light.counter, 0), 1),
            focus: Swift.max(light.focus, 0)
        )
    }

    /// `Picture.Glass.Light.reflection(for:)`.
    func reflection(for normal: Vector<3, Double>) -> Double {
        let length = normal.length
        guard length > 0, length.isFinite else { return 0 }
        let sign: Double = normal[2] < 0 ? -1 : 1
        let n = (sign * normal[0] / length, sign * normal[1] / length, sign * normal[2] / length)
        var highlight = 0.0
        if shines {
            let cosine = size > 0 ? (n.0 * half.0 + n.1 * half.1 + n.2 * half.2) / size : 0
            highlight = cosine > 0 ? strength * Double.math.pow(cosine, gloss) : 0
        }
        let edge = 1 - Swift.min(Swift.max(n.2, 0), 1)
        let falloff = edge > 0 ? Double.math.pow(edge, power) : (power == 0 ? 1 : 0)
        let shone = sheen * falloff * side(of: n)
        return Swift.min(Swift.max(highlight + shone, 0), 1)
    }

    /// `Picture.Glass.Light.side(of:)`.
    func side(of n: (Double, Double, Double)) -> Double {
        let across = (n.0 * n.0 + n.1 * n.1).squareRoot()
        let light = self.across
        guard across > 0, light > 0, across.isFinite, light.isFinite else { return 1 }
        let direction = self.light.direction
        let a = (n.0 * direction[0] + n.1 * direction[1]) / (across * light)
        let toward = (1 + a) / 2
        let away = (1 - a) / 2
        let f = focus
        func power(_ value: Double) -> Double { f == 2 ? value * value : (value > 0 ? Double.math.pow(value, f) : (f == 0 ? 1 : 0)) }
        return power(toward) + counter * power(away)
    }

    /// `Picture.Glass.Light.reflection(for:tilt:)`.
    func reflection(for normal: Vector<3, Double>, tilt: Double) -> Double {
        guard tilt != 1 else { return reflection(for: normal) }
        let length = normal.length
        let across = (normal[0] * normal[0] + normal[1] * normal[1]).squareRoot()
        guard length > 0, across > 0, length.isFinite else { return reflection(for: normal) }
        let sign: Double = normal[2] < 0 ? -1 : 1
        let angle = Swift.min(Double.atan2(across, abs(normal[2])) * Swift.max(tilt, 0), Double.pi / 2)
        let lean = Double.sin(angle) / across
        return reflection(for: Vector([normal[0] * lean, normal[1] * lean, sign * Double.cos(angle)]))
    }

    /// `Picture.Glass.Light.line(at:across:)`.
    func line(at inward: Double, across: Vector<2, Double>) -> Double {
        let width = light.width
        guard width > 0, inward >= 0, inward.isFinite else { return 0 }
        let u = inward / width
        let profile: Double
        if u <= 1 {
            profile = 1
        } else if u >= 2.5 {
            profile = 0
        } else {
            profile = 1 - Double.math.smoothstep(u, from: 1, to: 2.5)
        }
        guard profile > 0 else { return 0 }
        return Swift.min(Swift.max(light.line, 0), 1) * profile * side(of: (across[0], across[1], 0))
    }
}
