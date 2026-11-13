import Numeric
extension Picture.Reading {
    /// A character found in a picture: its origin in picture space, the angle of its baseline, its size and advance.
    struct Placed: Sendable {
        var scalar: Unicode.Scalar
        var x: Double
        var y: Double
        var angle: Double
        var size: Double
        var advance: Double
    }
}

extension Picture.Reading.Placed {
    /// How far the origin lies across the baseline's direction.
    var baseline: Double {
        -Double.sin(angle) * x + Double.cos(angle) * y
    }

    /// How far the origin lies along the baseline's direction.
    var along: Double {
        Double.cos(angle) * x + Double.sin(angle) * y
    }
}
