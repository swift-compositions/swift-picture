import Picture

extension Picture.Renderer.CPU {
    /// How a renderer gathers light a dispersive glass parts: the picture read at as many wavelengths as the
    /// colours part by pixels, and those reads gathered by the spectrum's weights.
    enum Spectra {
        /// The most wavelengths one point is read at.
        static let limit = 32

        /// The spectra of every count up to the limit, made once.
        static let table: [Picture.Glass.Spectrum] = (0...limit).map { Picture.Glass.Spectrum(count: $0) }
    }
}

extension Picture.Renderer.CPU.Spectra {
    /// The picture as a dispersive refraction shows it at a point: `read` gives where light of an index reads, in
    /// raster space, and `sample` the picture there. Where the shortest and the longest visible wavelengths read
    /// less than a quarter of a pixel apart, the point is read once at the glass's own index; otherwise at
    /// `Picture.Glass.Spectrum.count(for:)` wavelengths, so neighbouring wavelengths land about a pixel apart and
    /// a bright edge fans into a smooth rainbow, gathered by the spectrum's weights.
    static func pixel(
        _ refraction: Picture.Glass.Refraction,
        read: (_ index: Refraction.Index<Double>) -> (x: Double, y: Double),
        sample: (_ x: Double, _ y: Double) -> Picture.Pixel
    ) -> Picture.Pixel {
        let own = read(refraction.index)
        guard refraction.medium.isDispersive else { return sample(own.x, own.y) }
        let range = Picture.Glass.Spectrum.range
        let short = read(refraction.index(at: range.lowerBound))
        let long = read(refraction.index(at: range.upperBound))
        let spread = ((short.x - long.x) * (short.x - long.x) + (short.y - long.y) * (short.y - long.y)).squareRoot()
        let count = Picture.Glass.Spectrum.count(for: spread, limit: limit)
        guard count > 1 else { return sample(own.x, own.y) }
        let spectrum = table[count]
        var reads: [Picture.Pixel] = []
        reads.reserveCapacity(count)
        for wavelength in spectrum.wavelengths {
            let place = read(refraction.index(at: wavelength))
            reads.append(sample(place.x, place.y))
        }
        return spectrum.gathered(reads)
    }
}
