import Picture

extension Picture.Renderer.CPU.Hit {
    /// A hit without its weights, for a surface that is one colour all over: the nearest triangle's number in
    /// the stage's list and its depth at the sample point; a number below zero where none is.
    struct Nearest {
        var triangle: Int
        var depth: Double
    }
}

extension Picture.Renderer.CPU.Hit.Nearest {
    /// No triangle.
    static var none: Self { Self(triangle: -1, depth: .infinity) }
}
