import Numeric
public import Vector

extension Picture.Scene.Material.Glass {
    /// A glass's colours as working pixels: `pixel(over:facing:)` of a shading is that of its glass, bit for bit.
    public struct Shading: Sendable {
        let tint: Picture.Pixel
        let light: Light?
        let shine: Picture.Pixel
        let above: Picture.Pixel?
        let below: Picture.Pixel?
    }
}

extension Picture.Scene.Material.Glass.Shading {
    /// The tint over what the glass reads, and on top the light it reflects where its unit normal in eye space is
    /// `normal`, added.
    public func pixel(over behind: Picture.Pixel, facing normal: Vector<3, Double>) -> Picture.Pixel {
        lit(tint.composited(over: behind), facing: normal)
    }

    /// The pixel of glass with a body. Red, green and blue each come from the pixel that colour's light reads,
    /// with the mean of their alphas. The tint is taken on along the way: over them by the share
    /// 1 - (1 - a)^length, for a tint of alpha a and a path of `length` scene units inside the body. Where there
    /// are surroundings, those in the direction `leaving` are mixed in by `beyond`, the share of the light that
    /// misses the picture behind, and then those in the direction `mirrored` by `share`, what the surface
    /// mirrors. On top comes the light the glass reflects where its unit normal in eye space is `normal`, added.
    public func pixel(
        over behind: InlineArray<3, Picture.Pixel>,
        through length: Double,
        leaving: Vector<3, Double>,
        beyond: Double,
        mirroring mirrored: Vector<3, Double>,
        by share: Double,
        facing normal: Vector<3, Double>
    ) -> Picture.Pixel {
        let split = Picture.Pixel(
            color: .init(red: behind[0].color.red, green: behind[1].color.green, blue: behind[2].color.blue),
            alpha: (behind[0].alpha + behind[1].alpha + behind[2].alpha) / 3
        )
        var coated = split
        if tint.alpha > 0, length > 0 {
            let taken = tint.alpha < 1 ? 1 - Float(Double.exp(length * Double.log(Double(1 - tint.alpha)))) : 1
            coated = tint.composited(over: split, coverage: taken / tint.alpha)
        }
        if let above, let below {
            let outside = below.interpolated(to: above, at: Float(Picture.Scene.Material.Glass.Surroundings.share(toward: leaving)))
            coated = coated.interpolated(to: outside, at: Float(Swift.min(Swift.max(beyond, 0), 1)))
            let around = below.interpolated(to: above, at: Float(Picture.Scene.Material.Glass.Surroundings.share(toward: mirrored)))
            coated = coated.interpolated(to: around, at: Float(Swift.min(Swift.max(share, 0), 1)))
        }
        return lit(coated, facing: normal)
    }

    /// A pixel of the glass with the light it reflects at a normal added.
    func lit(_ coated: Picture.Pixel, facing normal: Vector<3, Double>) -> Picture.Pixel {
        guard let light else { return coated }
        let share = Float(light.reflection(for: normal))
        guard share > 0 else { return coated }
        return shine.composited(over: coated, operator: .lighter, coverage: share)
    }
}
