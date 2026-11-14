import Numeric
import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A glass brightens, saturates, frosts and casts shadows by its laws` {}
}

extension `Picture Tests`.`A glass brightens, saturates, frosts and casts shadows by its laws` {
    typealias Tests = `Picture Tests`

    @Test
    func `Gain and saturation move each colour away from the luminance and scale it, held to the alpha`() {
        let pixel = Tests.pixel(0.3, 0.5, 0.1, 0.8)
        #expect(Picture.Glass.saturated(pixel, by: 1, gain: 1) == pixel)
        let luminance: Float = 0.2126 * 0.3 + 0.7152 * 0.5 + 0.0722 * 0.1
        let moved = Picture.Glass.saturated(pixel, by: 1.5, gain: 1.2)
        for (value, component) in [(Float(0.3), moved.color.red), (0.5, moved.color.green), (0.1, moved.color.blue)] {
            let law = Swift.min(Swift.max(1.2 * (luminance + (value - luminance) * 1.5), 0), 0.8)
            #expect(Tests.close(component, law, within: 1e-6))
        }
        #expect(moved.alpha == 0.8)
        // No saturation leaves only the luminance, times the gain; a large gain is held to the alpha.
        let grey = Picture.Glass.saturated(pixel, by: 0, gain: 1)
        #expect(Tests.close(grey.color.red, luminance) && Tests.close(grey.color.green, luminance) && Tests.close(grey.color.blue, luminance))
        let held = Picture.Glass.saturated(pixel, by: 1, gain: 10)
        #expect(held.color.red == 0.8 && held.color.green == 0.8 && held.color.blue == 0.8)
    }

    @Test
    func `Frosting is the square root of how squarely the surface faces the eye`() {
        #expect(Picture.Glass.frosting(facing: Vector([0, 0, 1])) == 1)
        #expect(Picture.Glass.frosting(facing: Vector([0, 0, -1])) == 1)
        #expect(Picture.Glass.frosting(facing: Vector([1, 0, 0])) == 0)
        #expect(Tests.close(Picture.Glass.frosting(facing: Vector([0.8, 0, 0.36])), 0.6, within: 1e-12))
        let shares = stride(from: 0.0, through: 1, by: 0.05).map { Picture.Glass.frosting(facing: Vector([(1 - $0 * $0).squareRoot(), 0, $0])) }
        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test
    func `A shadow's edge stands within a hundredth of a Gaussian-blurred edge`() {
        for softness in [0.5, 2, 16] {
            let shadow = Picture.Glass.Shadow(softness: softness)
            for step in -400...400 {
                let distance = Double(step) / 50 * softness
                let gaussian = Double.math.erfc(distance / (softness * 2.0.squareRoot())) / 2
                #expect(abs(shadow.share(at: distance) - gaussian) < 0.01, "softness \(softness), distance \(distance)")
            }
        }
    }
}
