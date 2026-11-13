import Numeric
public import Vector

extension Picture.Glass {
    /// A glass's colours as working pixels: `pixel(over:facing:)` of a shading is that of its glass, bit for bit.
    public struct Shading: Sendable {
        let tint: Picture.Pixel
        let light: Light?
        let shine: Picture.Pixel
        let above: Picture.Pixel?
        let below: Picture.Pixel?

        /// The gain and the saturation the glass gives what it reads.
        let gain: Float
        let saturation: Float

        /// The adaptation, or none.
        let adaptation: Picture.Glass.Adaptation?
    }
}

extension Picture.Glass.Shading {
    /// The tint over what the glass reads, and on top the light it reflects where its unit normal in eye space is
    /// `normal`, added.
    public func pixel(over behind: Picture.Pixel, facing normal: Vector<3, Double>) -> Picture.Pixel {
        lit(coat(behind), facing: normal)
    }

    /// What the glass reads, saturated, adapted and then under its tint: `Picture.Glass.saturated(_:by:)`, then
    /// `Picture.Glass.Adaptation.pixel(_:)`, and the tint over that.
    public func coat(_ behind: Picture.Pixel) -> Picture.Pixel {
        tint.composited(over: adapted(behind))
    }

    /// A pixel made as bright and vivid as the gain and saturation say, then moved toward the adaptation's colour, as
    /// `Picture.Glass.Adaptation.pixel(_:)` moves it.
    func adapted(_ read: Picture.Pixel) -> Picture.Pixel {
        let pixel = Picture.Glass.saturated(read, by: saturation, gain: gain)
        guard let adaptation, adaptation.strength > 0 else { return pixel }
        return adaptation.pixel(pixel)
    }

    /// The pixel of glass with a body. Red, green and blue each come from the pixel that colour's light reads,
    /// with the mean of their alphas. The tint is taken on along the way: over them by the share
    /// 1 - (1 - a)^length, for a tint of alpha a and a path inside the body `length` times as long as the glass
    /// is thick, 1 for a pane. Where there
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
        facing normal: Vector<3, Double>,
        outline: Picture.Glass.Outline? = nil,
        tilts: InlineArray<3, Double> = [1, 1, 1]
    ) -> Picture.Pixel {
        let split = Picture.Pixel(
            color: .init(red: behind[0].color.red, green: behind[1].color.green, blue: behind[2].color.blue),
            alpha: (behind[0].alpha + behind[1].alpha + behind[2].alpha) / 3
        )
        var coated = adapted(split)
        if tint.alpha > 0, length > 0 {
            let taken = tint.alpha < 1 ? 1 - Float(Double.exp(length * Double.log(Double(1 - tint.alpha)))) : 1
            coated = tint.composited(over: coated, coverage: taken / tint.alpha)
        }
        if let above, let below {
            let outside = below.interpolated(to: above, at: Float(Picture.Glass.Surroundings.share(toward: leaving)))
            coated = coated.interpolated(to: outside, at: Float(Swift.min(Swift.max(beyond, 0), 1)))
            let around = below.interpolated(to: above, at: Float(Picture.Glass.Surroundings.share(toward: mirrored)))
            coated = coated.interpolated(to: around, at: Float(Swift.min(Swift.max(share, 0), 1)))
        }
        return lit(coated, facing: normal, outline: outline, tilts: tilts)
    }

    /// A pixel of the glass with the light it reflects added: at the normal (`Picture.Glass.Light.reflection(for:)`)
    /// and, where the point's place from the outline is known, the line along it (`Picture.Glass.Light.line(at:across:)`).
    /// Each colour takes its own tilt: its reflection at the normal leaned by it
    /// (`Picture.Glass.Light.reflection(for:tilt:)`) and its line at `inward` times it, so with dispersion the
    /// light parts into colours as the light bent through the glass does, and without it, tilts of 1, every colour
    /// takes the same share. The result is held at white: no colour above its alpha.
    public func lit(
        _ coated: Picture.Pixel,
        facing normal: Vector<3, Double>,
        outline: Picture.Glass.Outline?,
        tilts: InlineArray<3, Double>
    ) -> Picture.Pixel {
        guard let light else { return coated }
        let neutral = tilts[0] == 1 && tilts[1] == 1 && tilts[2] == 1
        func share(_ tilt: Double) -> Float {
            var total = tilt == 1 ? light.reflection(for: normal) : light.reflection(for: normal, tilt: tilt)
            if let outline { total += light.line(at: outline.inward * tilt, across: (outline.x, outline.y)) }
            return Float(Swift.min(Swift.max(total, 0), 1))
        }
        if neutral {
            let one = share(1)
            return one > 0 ? Self.held(shine.composited(over: coated, operator: .lighter, coverage: one)) : coated
        }
        var channels = InlineArray<3, Float>(repeating: 0)
        var alpha: Float = coated.alpha
        var channel = 0
        while channel < 3 {
            let amount = share(tilts[channel])
            let shone = amount > 0 ? shine.composited(over: coated, operator: .lighter, coverage: amount) : coated
            channels[channel] = channel == 0 ? shone.color.red : channel == 1 ? shone.color.green : shone.color.blue
            if channel == 1 { alpha = shone.alpha }
            channel += 1
        }
        return Self.held(Picture.Pixel(color: .init(red: channels[0], green: channels[1], blue: channels[2]), alpha: alpha))
    }

    /// A pixel with each colour held to 0 up to its alpha and its alpha to 0…1, as light added to glass saturates
    /// at white.
    static func held(_ pixel: Picture.Pixel) -> Picture.Pixel {
        let alpha = Swift.min(Swift.max(pixel.alpha, 0), 1)
        func hold(_ value: Float) -> Float { Swift.min(Swift.max(value, 0), alpha) }
        return Picture.Pixel(color: .init(red: hold(pixel.color.red), green: hold(pixel.color.green), blue: hold(pixel.color.blue)), alpha: alpha)
    }

    /// A pixel of the glass with the light it reflects at a normal added.
    func lit(_ coated: Picture.Pixel, facing normal: Vector<3, Double>) -> Picture.Pixel {
        guard let light else { return coated }
        let share = Float(light.reflection(for: normal))
        guard share > 0 else { return coated }
        return Self.held(shine.composited(over: coated, operator: .lighter, coverage: share))
    }
}
