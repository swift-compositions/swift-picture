import Color_Standard
public import Refraction

extension Picture.Glass {
    /// The visible spectrum cut into wavelengths at which a dispersive glass is sampled, each with the share of
    /// red, green and blue it gives: light that a glass parts by wavelength is gathered back into a pixel by
    /// these shares, so a white edge seen through a dispersive rim fans into a smooth rainbow.
    public struct Spectrum: Sendable, Hashable {
        /// The wavelengths, from short to long.
        public let wavelengths: [Refraction.Wavelength<Double>]

        /// For each wavelength, its share of red, green and blue; each colour's shares add up to 1.
        public let weights: [Weight]
    }
}

extension Picture.Glass.Spectrum {
    /// The visible range sampled, 400 to 700 nanometres.
    public static let range: ClosedRange<Refraction.Wavelength<Double>> =
        Refraction.Wavelength(nanometres: 400)...Refraction.Wavelength(nanometres: 700)

    /// `count` wavelengths at the midpoints of as many equal parts of `range`, each weighted by `response(at:)`
    /// and every colour's weights divided by their sum, so a flat white is gathered back to white:
    /// `Color.Spectrum(sampling:count:observer:)` of swift-color-standard with the analytic observer. One
    /// wavelength (and a count below one) is the d line alone with every share 1, so a spectrum of one is the
    /// plain bend at the glass's own index.
    public init(count: Int) {
        guard count > 1 else {
            self.init(wavelengths: [.d], weights: [Weight(red: 1, green: 1, blue: 1)])
            return
        }
        let spectrum = Color_Standard::Color.Spectrum(
            sampling: Self.range.lowerBound.nanometres...Self.range.upperBound.nanometres,
            count: Cardinal(UInt(count)),
            observer: .analytic
        )
        let wavelengths = spectrum.wavelengths.map { Refraction.Wavelength(nanometres: $0) }
        let weights = spectrum.weights.map { Weight(red: Float($0.red), green: Float($0.green), blue: Float($0.blue)) }
        self.init(wavelengths: wavelengths, weights: weights)
    }

    /// How much a wavelength excites linear red, green and blue: `Color.Spectrum.response(at:observer:)` of
    /// swift-color-standard, the CIE 1931 colour matching functions of swift-iso-11664 in the multi-lobe fit of
    /// Wyman, Sloan and Shirley (2013), taken from XYZ into linear sRGB, each held at 0 or more.
    public static func response(
        at wavelength: Refraction.Wavelength<Double>
    ) -> (red: Double, green: Double, blue: Double) {
        Color_Standard::Color.Spectrum.response(at: wavelength.nanometres, observer: .analytic)
    }

    /// Pixels read at each wavelength gathered into one: each colour the weighted sum of that colour over the
    /// reads, and alpha their mean.
    public func gathered(_ reads: [Picture.Pixel]) -> Picture.Pixel {
        var red: Float = 0
        var green: Float = 0
        var blue: Float = 0
        var alpha: Float = 0
        for (read, weight) in zip(reads, weights) {
            red += weight.red * read.color.red
            green += weight.green * read.color.green
            blue += weight.blue * read.color.blue
            alpha += read.alpha
        }
        return Picture.Pixel(color: .init(red: red, green: green, blue: blue), alpha: reads.isEmpty ? 0 : alpha / Float(reads.count))
    }

    /// How many wavelengths a bend that parts the shortest and the longest wavelength by `spread` pixels needs
    /// so that neighbouring wavelengths land within about a pixel of each other: one where the colours do not
    /// part, and at most `limit`.
    public static func count(for spread: Double, limit: Int = 32) -> Int {
        guard spread.isFinite, spread > 0.25 else { return spread.isFinite ? 1 : limit }
        return Swift.min(Swift.max(Int(spread.rounded(.up)) + 2, 3), limit)
    }
}
