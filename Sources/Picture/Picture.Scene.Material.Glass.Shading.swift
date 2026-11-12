public import Vector

extension Picture.Scene.Material.Glass {
    /// A glass's colours as working pixels: `pixel(over:facing:)` of a shading is that of its glass, bit for bit.
    public struct Shading: Sendable {
        let tint: Picture.Pixel
        let light: Light?
        let shine: Picture.Pixel
    }
}

extension Picture.Scene.Material.Glass.Shading {
    /// The tint over what the glass reads, and on top the light it reflects where its unit normal in eye space is
    /// `normal`, added.
    public func pixel(over behind: Picture.Pixel, facing normal: Vector<3, Double>) -> Picture.Pixel {
        let coated = tint.composited(over: behind)
        guard let light else { return coated }
        let share = Float(light.reflection(for: normal))
        guard share > 0 else { return coated }
        return shine.composited(over: coated, operator: .lighter, coverage: share)
    }
}
