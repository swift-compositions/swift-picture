public import Vector

extension Picture.Glass {
    /// Glass with a body: light bends where it goes into the surface and again where it comes out of the far
    /// side, so what is seen through a round body is turned over and squeezed toward its edges; the edges
    /// mirror their surroundings more than they pass; and the colours part a little where the bend is strong.
    public struct Refraction: Sendable, Hashable {
        /// The index of refraction of the body against what is around it: 1 bends nothing, 1.5 is window glass.
        public var index: Double

        /// How far behind the place light leaves the body the picture behind stands, in the scene's units
        /// along the eye's line of sight.
        public var distance: Double

        /// How little the index differs between wavelengths: the Abbe number V = (n_d − 1) / (n_F − n_C), about
        /// 60 for crown glass, 30 for dense flint and 17 for the most dispersive optical glass; lower parts the
        /// colours more. Infinite, the default, is one index for every wavelength.
        public var abbe: Double

        /// What the surface mirrors, by the share Fresnel's equations give, or nothing.
        public var surroundings: Picture.Glass.Surroundings?

        public init(
            index: Double = 1.5,
            distance: Double = 1,
            abbe: Double = .infinity,
            surroundings: Picture.Glass.Surroundings? = nil
        ) {
            self.index = index
            self.distance = distance
            self.abbe = abbe
            self.surroundings = surroundings
        }
    }
}

extension Picture.Glass.Refraction {
    /// The Fraunhofer lines the Abbe number is defined at, in nanometres: d (helium, yellow), F (hydrogen, blue)
    /// and C (hydrogen, red).
    public static let lines: (d: Double, F: Double, C: Double) = (587.56, 486.13, 656.27)

    /// The index at a wavelength in nanometres, by Cauchy's law n(λ) = A + B / λ²: B makes n_F − n_C equal
    /// (index − 1) / abbe and A makes n_d equal `index`. So the index at the d line is `index` exactly, shorter
    /// wavelengths bend more, and an infinite Abbe number, or one that is not positive, gives `index` at every
    /// wavelength. Never below 1.
    public func index(at wavelength: Double) -> Double {
        let n = Swift.max(index, 1)
        guard abbe.isFinite, abbe > 0, wavelength > 0, wavelength.isFinite else { return n }
        let lines = Self.lines
        let b = (n - 1) / abbe / (1 / (lines.F * lines.F) - 1 / (lines.C * lines.C))
        return Swift.max(n + b * (1 / (wavelength * wavelength) - 1 / (lines.d * lines.d)), 1)
    }

    /// For red, green and blue, the mean over the spectrum of how far light bends compared with light of the
    /// glass's own index: Σ w(λ) (n(λ) − 1) / (index − 1) over `Picture.Glass.Spectrum(count: 32)` with that
    /// colour's weights w. All three are 1 for an infinite Abbe number or an index of 1; with dispersion blue's is
    /// above 1 and red's below. `Picture.Glass.Shading.lit(_:facing:tilts:)` leans each colour's sheen by them.
    public var tilts: InlineArray<3, Double> {
        let n = Swift.max(index, 1)
        guard abbe.isFinite, abbe > 0, n > 1 else { return [1, 1, 1] }
        let spectrum = Picture.Glass.Spectrum(count: 32)
        var sums = InlineArray<3, Double>(repeating: 0)
        for (wavelength, weight) in zip(spectrum.wavelengths, spectrum.weights) {
            let ratio = (index(at: wavelength) - 1) / (n - 1)
            sums[0] += Double(weight.red) * ratio
            sums[1] += Double(weight.green) * ratio
            sums[2] += Double(weight.blue) * ratio
        }
        return sums
    }

    /// A unit direction after it crosses a surface, by Snell's law: `ratio` is the index of the side it comes
    /// from over the index of the side it goes into, and `normal` is the surface's unit normal on the side it
    /// comes from. It is nil where no light crosses: beyond the critical angle, on the way out of the denser side.
    public static func bent(_ direction: Vector<3, Double>, at normal: Vector<3, Double>, ratio: Double) -> Vector<3, Double>? {
        let cosine = -(direction[0] * normal[0] + direction[1] * normal[1] + direction[2] * normal[2])
        let inside = 1 - ratio * ratio * (1 - cosine * cosine)
        guard inside >= 0 else { return nil }
        let along = ratio * cosine - inside.squareRoot()
        return Vector([
            ratio * direction[0] + along * normal[0],
            ratio * direction[1] + along * normal[1],
            ratio * direction[2] + along * normal[2],
        ])
    }

    /// A direction after a surface with a unit normal mirrors it.
    public static func mirrored(_ direction: Vector<3, Double>, at normal: Vector<3, Double>) -> Vector<3, Double> {
        let twice = 2 * (direction[0] * normal[0] + direction[1] * normal[1] + direction[2] * normal[2])
        return Vector([direction[0] - twice * normal[0], direction[1] - twice * normal[1], direction[2] - twice * normal[2]])
    }

    /// The share of unpolarised light the surface mirrors, 0 to 1, where light meets it from outside at an angle
    /// whose cosine to the normal is `cosine`: the mean of Fresnel's two equations. It is ((n - 1) / (n + 1))²
    /// head-on and 1 at a grazing angle.
    public func reflectance(cosine: Double) -> Double {
        let n = Swift.max(index, 1)
        let c = Swift.min(Swift.max(cosine, 0), 1)
        let within = (1 - (1 - c * c) / (n * n)).squareRoot()
        let across = (c - n * within) / (c + n * within)
        let along = (n * c - within) / (n * c + within)
        guard across.isFinite, along.isFinite else { return 1 }
        return (across * across + along * along) / 2
    }
}
