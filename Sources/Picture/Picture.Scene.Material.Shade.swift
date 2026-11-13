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
    /// The light a surface takes at a normal in eye space: Lambert's cosine to the lamp, held at 0 or more, plus
    /// `rim` times one less the normal's z raised to `sharpness`. Either side of a surface takes light, so a
    /// normal facing away from the eye is turned to face it first. A normal of no length takes none, and a lamp
    /// direction of no length gives no cosine.
    public func light(facing normal: Vector<3, Double>) -> Double {
        let length = (normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2]).squareRoot()
        guard length > 0, length.isFinite else { return 0 }
        let sign: Double = normal[2] < 0 ? -1 : 1
        let n = (sign * normal[0] / length, sign * normal[1] / length, sign * normal[2] / length)
        let reach = (toward[0] * toward[0] + toward[1] * toward[1] + toward[2] * toward[2]).squareRoot()
        var cosine = 0.0
        if reach > 0, reach.isFinite {
            cosine = Swift.max((n.0 * toward[0] + n.1 * toward[1] + n.2 * toward[2]) / reach, 0)
        }
        let edge = 1 - Swift.min(Swift.max(n.2, 0), 1)
        let power = Swift.max(sharpness, 0)
        let falloff = edge > 0 ? Double.exp(power * Double.log(edge)) : (power == 0 ? 1 : 0)
        return cosine + rim * falloff
    }

    /// The pixel a surface shows at a normal in eye space: the ramp's pixel at `light(facing:)`. A renderer that
    /// reads many takes the ramp's `ramp` once and reads it at the light.
    public func pixel(facing normal: Vector<3, Double>) -> Picture.Pixel {
        ramp.pixel(at: Float(light(facing: normal)))
    }
}
