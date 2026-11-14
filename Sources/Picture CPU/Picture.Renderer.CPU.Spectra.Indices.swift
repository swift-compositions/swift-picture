import Picture

extension Picture.Renderer.CPU.Spectra {
    /// A refraction's indices at the wavelengths the spectra read, worked out once for a glass instead of at
    /// every point: its own index, those at both ends of the visible range, and for each count up to the limit
    /// the indices at that spectrum's wavelengths, each `Picture.Glass.Refraction.index(at:)`.
    struct Indices {
        let own: Refraction.Index<Double>
        let short: Refraction.Index<Double>
        let long: Refraction.Index<Double>
        let dispersive: Bool

        /// The indices of every spectrum one after another, and where each count's own begin.
        let indices: [Refraction.Index<Double>]
        let starts: [Int]

        init(_ refraction: Picture.Glass.Refraction) {
            let range = Picture.Glass.Spectrum.range
            self.own = refraction.index
            self.dispersive = refraction.medium.isDispersive
            self.short = refraction.index(at: range.lowerBound)
            self.long = refraction.index(at: range.upperBound)
            var indices: [Refraction.Index<Double>] = []
            var starts: [Int] = []
            if dispersive {
                for spectrum in Picture.Renderer.CPU.Spectra.table {
                    starts.append(indices.count)
                    for wavelength in spectrum.wavelengths { indices.append(refraction.index(at: wavelength)) }
                }
            }
            self.indices = indices
            self.starts = starts
        }
    }
}
