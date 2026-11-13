extension Picture.Reading {
    /// A character as its font draws it at size 1: its contours and its advance.
    struct Letter: Sendable {
        var scalar: Unicode.Scalar
        var contours: [Contour]
        var advance: Double
    }
}
