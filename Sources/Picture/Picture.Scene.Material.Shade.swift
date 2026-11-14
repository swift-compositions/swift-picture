import Numeric
public import Vector

extension Picture.Scene.Material {
    /// A surface lit by one lamp, with a rim light where it turns away from the eye, and coloured by how much
    /// light it takes: a colour ramp read at that light. Read from 0 for the dark side up to 1 where the surface
    /// faces the lamp, and past 1 where the rim adds to it, so the ramp names the unlit, the lit and the glowing
    /// colour of the surface.
    public struct Shade: Sendable, Hashable {
        /// The colour at the light a point takes.
        public var ramp: Picture.Gradient

        /// Toward the lamp, in eye space, where the eye looks along minus z; its length does not matter.
        public var toward: Vector<3, Double>

        /// How much light the rim adds where the surface is edge-on to the eye.
        public var rim: Double

        /// How tight the rim is: the power one less the normal's z is raised to.
        public var sharpness: Double

        public init(ramp: Picture.Gradient, toward: Vector<3, Double>, rim: Double = 0, sharpness: Double = 2) {
            self.ramp = ramp
            self.toward = toward
            self.rim = rim
            self.sharpness = sharpness
        }
    }
}

extension Picture.Scene.Material.Shade {
    /// The light a surface takes at a normal in eye space: `cosine(facing:)` plus `rim(facing:)`. Read from 0 on
    /// the dark side, 1 where the surface faces the lamp, and past 1 where the rim adds to it.
    public func light(facing normal: Vector<3, Double>) -> Double {
        Prepared(self).light(facing: normal)
    }

    /// The lamp's part of the light at a normal in eye space: Lambert's cosine to the lamp, held at 0 or more.
    /// Either side of a surface takes light, so a normal facing away from the eye is turned to face it first. A
    /// normal of no length and a lamp direction of no length give 0.
    public func cosine(facing normal: Vector<3, Double>) -> Double {
        guard let n = Self.facing(normal) else { return 0 }
        let reach = toward.length
        guard reach > 0, reach.isFinite else { return 0 }
        return Swift.max((n.0 * toward[0] + n.1 * toward[1] + n.2 * toward[2]) / reach, 0)
    }

    /// The rim's part of the light at a normal in eye space: `rim` times one less the normal's z raised to
    /// `sharpness`, the normal turned to face the eye first; 0 for a normal of no length. A thing that is not a
    /// mesh, such as a point or a sprite, is lit by the same law from a normal of its own, through `cosine(facing:)`,
    /// this and the ramp read at their sum.
    public func rim(facing normal: Vector<3, Double>) -> Double {
        guard let n = Self.facing(normal) else { return 0 }
        let edge = 1 - Swift.min(Swift.max(n.2, 0), 1)
        let power = Swift.max(sharpness, 0)
        let falloff = edge > 0 ? Double.math.pow(edge, power) : (power == 0 ? 1 : 0)
        return rim * falloff
    }

    /// The pixel a surface shows at a normal in eye space: the ramp's pixel at `light(facing:)`. A renderer that
    /// reads many takes the ramp's `ramp` once and reads it at the light.
    public func pixel(facing normal: Vector<3, Double>) -> Picture.Pixel {
        pixel(at: light(facing: normal))
    }

    /// The pixel of a light, however it was found: the ramp's pixel there.
    public func pixel(at light: Double) -> Picture.Pixel {
        ramp.pixel(at: Float(light))
    }

    /// A normal at unit length turned to face the eye, nil for one of no length.
    static func facing(_ normal: Vector<3, Double>) -> (Double, Double, Double)? {
        let length = normal.length
        guard length > 0, length.isFinite else { return nil }
        let sign: Double = normal[2] < 0 ? -1 : 1
        return (sign * normal[0] / length, sign * normal[1] / length, sign * normal[2] / length)
    }
}
