public import Refraction

extension Picture.Glass {
    /// Glass with a body: light bends where it goes into the surface and again where it comes out of the far
    /// side, so what is seen through a round body is enlarged when the picture is near behind it and turned
    /// over when it is far, and squeezed toward its edges; the edges mirror their surroundings more than they
    /// pass; and the colours part a little where the bend is strong. The laws of the bend, the mirrored share
    /// and the parting are swift-refraction's. Where the picture behind stands and what the surface mirrors
    /// belong to where the glass stands: a pane's `distance` and `surroundings`, a scene's model's `distance`
    /// and the scene's `surroundings`.
    public struct Body: Sendable, Hashable {
        /// The body's medium against what is around it: its index at the d line, where 1 bends nothing and
        /// 1.5 is window glass, and its Abbe number, how little the index differs between wavelengths (about
        /// 60 for crown glass, 30 for dense flint and 17 for the most dispersive optical glass; lower parts
        /// the colours more, and infinite is one index for every wavelength).
        public var medium: Refraction.Cauchy<Double>

        /// A body of index `index` at the d line and Abbe number `abbe`; the default, 45, lies between crown glass
        /// and dense flint, so colours part only where the bend is steep, as a faint fringe.
        public init(index: Refraction.Index<Double> = 1.5, abbe: Double = 45) {
            self.medium = .init(index: index, abbe: abbe)
        }
    }
}

extension Picture.Glass.Body {
    /// The glass's own index, its medium's at the d line, never below vacuum's: a glass bends toward the
    /// normal going in.
    public var index: Refraction.Index<Double> {
        Swift.max(medium.index, .vacuum)
    }

    /// The index at a wavelength, by the medium's Cauchy law, never below vacuum's.
    public func index(at wavelength: Refraction.Wavelength<Double>) -> Refraction.Index<Double> {
        Swift.max(Refraction.Cauchy(index: index, abbe: medium.abbe).index(at: wavelength), .vacuum)
    }

    /// How many times a ball of this glass of a `radius` enlarges the picture `distance` behind it near its
    /// middle, both in units of the picture: `Refraction.Ball.enlargement(at:)`, index / (2 − index) at no
    /// distance, turned over past the focus. An index of 1 or below enlarges nothing, and a radius that is not
    /// positive gives 1.
    public func enlargement(radius: Double, distance: Double) -> Double {
        guard index > .vacuum, radius > 0 else { return 1 }
        return Refraction.Ball(index: index, radius: radius).enlargement(at: distance)
    }

    /// For red, green and blue, the mean over the spectrum of how far light bends compared with light of the
    /// glass's own index: Σ w(λ) (n(λ) − 1) / (index − 1) over `Picture.Glass.Spectrum(count: 32)` with that
    /// colour's weights w. All three are 1 for an infinite Abbe number or an index of 1; with dispersion blue's is
    /// above 1 and red's below. `Picture.Glass.Shading.pixel(over:through:leaving:beyond:mirroring:by:facing:outline:tilts:)`
    /// leans each colour's light by them.
    public var tilts: InlineArray<3, Double> {
        let n = index.value
        guard medium.isDispersive, n > 1 else { return [1, 1, 1] }
        let spectrum = Picture.Glass.Spectrum(count: 32)
        var sums = InlineArray<3, Double>(repeating: 0)
        for (wavelength, weight) in zip(spectrum.wavelengths, spectrum.weights) {
            let ratio = (index(at: wavelength).value - 1) / (n - 1)
            sums[0] += Double(weight.red) * ratio
            sums[1] += Double(weight.green) * ratio
            sums[2] += Double(weight.blue) * ratio
        }
        return sums
    }
}
