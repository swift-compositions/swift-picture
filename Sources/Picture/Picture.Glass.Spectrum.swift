import Numeric

extension Picture.Glass {
    /// The visible spectrum cut into wavelengths at which a dispersive glass is sampled, each with the share of
    /// red, green and blue it gives: light that a glass parts by wavelength is gathered back into a pixel by
    /// these shares, so a white edge seen through a dispersive rim fans into a smooth rainbow.
    public struct Spectrum: Sendable, Hashable {
        /// The wavelengths in nanometres, from short to long.
        public let wavelengths: [Double]

        /// For each wavelength, its share of red, green and blue; each colour's shares add up to 1.
        public let weights: [Weight]
    }
}

extension Picture.Glass.Spectrum {
    /// A wavelength's share of red, green and blue.
    public struct Weight: Sendable, Hashable {
        public var red: Float
        public var green: Float
        public var blue: Float

        public init(red: Float, green: Float, blue: Float) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }
}

extension Picture.Glass.Spectrum {
    /// The visible range sampled, in nanometres.
    public static let range: ClosedRange<Double> = 400...700

    /// `count` wavelengths at the midpoints of as many equal parts of `range`, each weighted by `response(at:)`
    /// and every colour's weights divided by their sum, so a flat white is gathered back to white. One
    /// wavelength (and a count below one) is the d line alone with every share 1, so a spectrum of one is the
    /// plain bend at the glass's own index.
    public init(count: Int) {
        guard count > 1 else {
            self.init(wavelengths: [Picture.Glass.Refraction.lines.d], weights: [Weight(red: 1, green: 1, blue: 1)])
            return
        }
        let low = Self.range.lowerBound
        let width = Self.range.upperBound - low
        let wavelengths = (0..<count).map { low + width * (Double($0) + 0.5) / Double(count) }
        let raw = wavelengths.map(Self.response(at:))
        let total = raw.reduce((0.0, 0.0, 0.0)) { ($0.0 + $1.red, $0.1 + $1.green, $0.2 + $1.blue) }
        let weights = raw.map {
            Weight(
                red: total.0 > 0 ? Float($0.red / total.0) : 0,
                green: total.1 > 0 ? Float($0.green / total.1) : 0,
                blue: total.2 > 0 ? Float($0.blue / total.2) : 0
            )
        }
        self.init(wavelengths: wavelengths, weights: weights)
    }

    /// How much a wavelength in nanometres excites linear red, green and blue: the CIE 1931 colour matching
    /// functions in the multi-lobe fit of Wyman, Sloan and Shirley (2013), taken from XYZ into linear sRGB, each
    /// held at 0 or more.
    public static func response(at wavelength: Double) -> (red: Double, green: Double, blue: Double) {
        func lobe(_ mean: Double, _ below: Double, _ above: Double) -> Double {
            let t = (wavelength - mean) / (wavelength < mean ? below : above)
            return Double.exp(-0.5 * t * t)
        }
        let x = 1.056 * lobe(599.8, 37.9, 31.0) + 0.362 * lobe(442.0, 16.0, 26.7) - 0.065 * lobe(501.1, 20.4, 26.2)
        let y = 0.821 * lobe(568.8, 46.9, 40.5) + 0.286 * lobe(530.9, 16.3, 31.1)
        let z = 1.217 * lobe(437.0, 11.8, 36.0) + 0.681 * lobe(459.0, 26.0, 13.8)
        return (
            Swift.max(3.2406 * x - 1.5372 * y - 0.4986 * z, 0),
            Swift.max(-0.9689 * x + 1.8758 * y + 0.0415 * z, 0),
            Swift.max(0.0557 * x - 0.2040 * y + 1.0570 * z, 0)
        )
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
