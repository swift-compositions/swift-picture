public import Refraction

extension Picture.Glass {
    /// Glass with a body: light bends where it goes into the surface and again where it comes out of the far
    /// side, so what is seen through a round body is enlarged when the picture is near behind it and turned
    /// over when it is far, and squeezed toward its edges; the edges mirror their surroundings more than they
    /// pass; and the colours part a little where the bend is strong. The laws of the bend, the mirrored share
    /// and the parting are swift-refraction's; the glass adds where the picture behind it stands and what
    /// its surface mirrors.
    public struct Refraction: Sendable, Hashable {
        /// The body's medium against what is around it: its index at the d line, where 1 bends nothing and
        /// 1.5 is window glass, and its Abbe number, how little the index differs between wavelengths (about
        /// 60 for crown glass, 30 for dense flint and 17 for the most dispersive optical glass; lower parts
        /// the colours more, and infinite is one index for every wavelength).
        public var medium: Refraction::Refraction.Cauchy<Double>

        /// How far behind the glass's back the picture behind stands, in units of the picture the glass is
        /// drawn in, as every length of a glass is: below a pane's flat bottom, and behind the plane across the
        /// line of sight through a body's farthest point from the eye. So one value lays the picture as far
        /// behind a pane as behind a sphere or a torus of the same size in the picture. A ball whose picture is
        /// nearer than about half its radius shows it upright and enlarged, as a glass ball held over a page
        /// does (`Refraction.Ball.enlargement(at:)`), and one farther than that turns it over.
        public var distance: Double

        /// What the surface mirrors, by the share Fresnel's equations give, or nothing.
        public var surroundings: Picture.Glass.Surroundings?

        /// A body of index `index` at the d line and Abbe number `abbe`; `Dispersion` names three strengths,
        /// and the default is `Dispersion.subtle`.
        public init(
            index: Refraction::Refraction.Index<Double> = 1.5,
            distance: Double = 1,
            abbe: Double = Dispersion.subtle,
            surroundings: Picture.Glass.Surroundings? = nil
        ) {
            self.medium = .init(index: index, abbe: abbe)
            self.distance = distance
            self.surroundings = surroundings
        }
    }
}

extension Picture.Glass.Refraction {
    /// The glass's own index, its medium's at the d line, never below vacuum's: a glass bends toward the
    /// normal going in.
    public var index: Refraction::Refraction.Index<Double> {
        Swift.max(medium.index, .vacuum)
    }

    /// The index at a wavelength, by the medium's Cauchy law, never below vacuum's.
    public func index(at wavelength: Refraction::Refraction.Wavelength<Double>) -> Refraction::Refraction.Index<Double> {
        Swift.max(Refraction::Refraction.Cauchy(index: index, abbe: medium.abbe).index(at: wavelength), .vacuum)
    }

    /// How many times a ball of this glass of a `radius` enlarges the picture `distance` behind it near its
    /// middle, both in units of the picture: `Refraction.Ball.enlargement(at:)`, index / (2 − index) at no
    /// distance, turned over past the focus. An index of 1 or below enlarges nothing, and a radius that is not
    /// positive gives 1.
    public func enlargement(radius: Double) -> Double {
        guard index > .vacuum, radius > 0 else { return 1 }
        return Refraction::Refraction.Ball(index: index, radius: radius).enlargement(at: distance)
    }

    /// For red, green and blue, the mean over the spectrum of how far light bends compared with light of the
    /// glass's own index: Σ w(λ) (n(λ) − 1) / (index − 1) over `Picture.Glass.Spectrum(count: 32)` with that
    /// colour's weights w. All three are 1 for an infinite Abbe number or an index of 1; with dispersion blue's is
    /// above 1 and red's below. `Picture.Glass.Shading.lit(_:facing:tilts:)` leans each colour's sheen by them.
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
