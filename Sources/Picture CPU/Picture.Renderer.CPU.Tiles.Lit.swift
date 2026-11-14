import Picture

extension Picture.Renderer.CPU.Tiles {
    /// A sprite as it is read: its centre, its radius, the square of a positive radius (0 for any other), and its
    /// colour's pixel.
    struct Lit {
        let x: Double
        let y: Double
        let radius: Double
        let reach: Double
        let pixel: Picture.Pixel
    }
}
