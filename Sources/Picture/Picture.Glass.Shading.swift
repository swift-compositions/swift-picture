import Numeric
public import Vector

extension Picture.Glass {
    /// A glass's colours as working pixels, made once for drawing many points of it: `pixel(over:…)` is the law
    /// of a glass's pixel.
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

        /// What is read many times worked out once: the light made ready, the lightness the adaptation moves
        /// toward, and the logarithm of what the tint lets through, by which a body's coat grows with its path.
        let prepared: Picture.Glass.Light.Prepared?
        let target: Float
        let through: Double
    }
}

extension Picture.Glass.Shading {
    /// A glass's colours made ready for drawing many points of it, with the surroundings its body mirrors where it
    /// stands, a pane's or a scene's; a skin mirrors nothing.
    public init(_ glass: Picture.Glass, surroundings: Picture.Glass.Surroundings? = nil) {
        let mirrored = glass.body == nil ? nil : surroundings
        let tint = glass.tint.pixel
        self.init(
            tint: tint,
            light: glass.light,
            shine: glass.light?.color.pixel ?? .transparent,
            above: mirrored?.above.pixel,
            below: mirrored?.below.pixel,
            gain: Float(glass.gain),
            saturation: Float(glass.saturation),
            adaptation: glass.adaptation,
            prepared: glass.light.map(Picture.Glass.Light.Prepared.init),
            target: glass.adaptation.map { Picture.Glass.Adaptation.lightness(of: $0.color.pixel) } ?? 0,
            through: Double.log(Double(1 - tint.alpha))
        )
    }
}

extension Picture.Glass.Shading {
    /// The one law of a glass's pixel, over the pixel of the picture behind that it reads. What it reads is made
    /// as bright and vivid as the gain and saturation say (`Picture.Glass.saturated(_:by:gain:)`) and moved toward
    /// the adaptation's colour (`Picture.Glass.Adaptation.pixel(_:)`). Then the tint: for a skin, `length` nil, it
    /// lies over that; through a body it is taken on along the way, over it by the share 1 - (1 - a)^length for a
    /// tint of alpha a and a path inside the body `length` times as long as the glass is thick, 1 for a pane.
    /// Where a body has surroundings, those in the direction `leaving` are mixed in by `beyond`, the share of the
    /// light that misses the picture behind, and then those in the direction `mirrored` by `share`, what the
    /// surface mirrors. Last, where the unit normal in eye space is known, comes the light the glass reflects there,
    /// added: at the normal (`Picture.Glass.Light.reflection(for:)`) and, where the point's place from the outline
    /// is known, the line along it (`Picture.Glass.Light.line(at:across:)`). Each colour takes its own tilt: its
    /// reflection at the normal leaned by it (`Picture.Glass.Light.reflection(for:tilt:)`) and its line at
    /// `inward` times it, so with dispersion the light parts into colours as the light bent through the glass
    /// does, and without it, tilts of 1, every colour takes the same share. The light is held at white: no colour
    /// above its alpha.
    public func pixel(
        over behind: Picture.Pixel,
        through length: Double? = nil,
        leaving: Vector<3, Double> = Vector([0, 0, -1]),
        beyond: Double = 0,
        mirroring mirrored: Vector<3, Double> = Vector([0, 0, -1]),
        by share: Double = 0,
        facing normal: Vector<3, Double>? = nil,
        outline: Picture.Glass.Outline? = nil,
        tilts: InlineArray<3, Double> = [1, 1, 1]
    ) -> Picture.Pixel {
        var coated = adapted(behind)
        if let length {
            if tint.alpha > 0, length > 0 {
                let taken = tint.alpha < 1 ? 1 - Float(Double.exp(length * through)) : 1
                coated = tint.composited(over: coated, coverage: taken / tint.alpha)
            }
            if let above, let below {
                let outside = below.interpolated(to: above, at: Float(Picture.Glass.Surroundings.share(toward: leaving)))
                coated = coated.interpolated(to: outside, at: Float(Swift.min(Swift.max(beyond, 0), 1)))
                let around = below.interpolated(to: above, at: Float(Picture.Glass.Surroundings.share(toward: mirrored)))
                coated = coated.interpolated(to: around, at: Float(Swift.min(Swift.max(share, 0), 1)))
            }
        } else {
            coated = tint.composited(over: coated)
        }
        guard let normal else { return coated }
        return lit(coated, facing: normal, outline: outline, tilts: tilts)
    }

    /// A pixel made as bright and vivid as the gain and saturation say, then moved toward the adaptation's colour, as
    /// `Picture.Glass.Adaptation.pixel(_:)` moves it.
    func adapted(_ read: Picture.Pixel) -> Picture.Pixel {
        let pixel = Picture.Glass.saturated(read, by: saturation, gain: gain)
        guard let adaptation, adaptation.strength > 0 else { return pixel }
        return adaptation.pixel(pixel, target: target)
    }

    /// A pixel of the glass with the light it reflects added, as `pixel(over:…)` adds it.
    func lit(
        _ coated: Picture.Pixel,
        facing normal: Vector<3, Double>,
        outline: Picture.Glass.Outline?,
        tilts: InlineArray<3, Double>
    ) -> Picture.Pixel {
        guard let light = prepared else { return coated }
        let neutral = tilts[0] == 1 && tilts[1] == 1 && tilts[2] == 1
        func share(_ tilt: Double) -> Float {
            var total = tilt == 1 ? light.reflection(for: normal) : light.reflection(for: normal, tilt: tilt)
            if let outline { total += light.line(at: outline.inward * tilt, across: (outline.outward[0], outline.outward[1])) }
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
}
