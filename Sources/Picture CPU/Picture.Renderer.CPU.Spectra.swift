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

extension Picture.Renderer.CPU.Spectra {
    /// The picture as a dispersive refraction shows it at a point: `read` gives where light of an index reads, in
    /// raster space, and `sample` the picture there. Where the shortest and the longest visible wavelengths read
    /// less than a quarter of a pixel apart, the point is read once at the glass's own index; otherwise at
    /// `Picture.Glass.Spectrum.count(for:)` wavelengths, so neighbouring wavelengths land about a pixel apart and
    /// a bright edge fans into a smooth rainbow, gathered by the spectrum's weights as
    /// `Picture.Glass.Spectrum.gathered(_:)` gathers them, each read added as it is made.
    static func pixel(
        _ indices: Indices,
        read: (_ index: Refraction.Index<Double>) -> (x: Double, y: Double),
        sample: (_ x: Double, _ y: Double) -> Picture.Pixel
    ) -> Picture.Pixel {
        let own = read(indices.own)
        guard indices.dispersive else { return sample(own.x, own.y) }
        let short = read(indices.short)
        let long = read(indices.long)
        let spread = ((short.x - long.x) * (short.x - long.x) + (short.y - long.y) * (short.y - long.y)).squareRoot()
        let count = Picture.Glass.Spectrum.count(for: spread, limit: limit)
        guard count > 1 else { return sample(own.x, own.y) }
        let spectrum = table[count]
        let start = indices.starts[count]
        var red: Float = 0
        var green: Float = 0
        var blue: Float = 0
        var alpha: Float = 0
        var number = 0
        let wavelengths = spectrum.wavelengths.count
        while number < wavelengths {
            let place = read(indices.indices[start + number])
            let pixel = sample(place.x, place.y)
            let weight = spectrum.weights[number]
            red += weight.red * pixel.color.red
            green += weight.green * pixel.color.green
            blue += weight.blue * pixel.color.blue
            alpha += pixel.alpha
            number += 1
        }
        return Picture.Pixel(color: .init(red: red, green: green, blue: blue), alpha: alpha / Float(wavelengths))
    }
}
