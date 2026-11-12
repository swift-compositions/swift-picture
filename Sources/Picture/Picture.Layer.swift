public import W3C_CSS_Compositing

extension Picture {
    /// A picture drawn on its own transparent sheet, changed by effects, and composited as one.
    public struct Layer: Sendable, Hashable {
        public var content: Picture
        public var effects: [Effect]
        public var opacity: Float
        public var blend: BlendMode
        public var `operator`: Compositing.Operator

        public init(
            _ content: Picture,
            effects: [Effect] = [],
            opacity: Float = 1,
            blend: BlendMode = .normal,
            operator: Compositing.Operator = .sourceOver
        ) {
            self.content = content
            self.effects = effects
            self.opacity = opacity
            self.blend = blend
            self.operator = `operator`
        }
    }
}

extension Picture.Layer {
    /// One pixel of the finished sheet put onto one pixel of what is behind.
    ///
    /// Under `lighter` the colours add without a limit, but alpha, which says how much of what is behind a
    /// pixel hides, is held at 1: light added to an opaque pixel leaves it opaque.
    public func composited(_ sheet: Picture.Pixel, over backdrop: Picture.Pixel) -> Picture.Pixel {
        let pixel = sheet.composited(over: backdrop, operator: `operator`, blend: blend, coverage: opacity)
        guard `operator` == .lighter, pixel.alpha > 1 else { return pixel }
        return Picture.Pixel(color: pixel.color, alpha: 1)
    }
}
