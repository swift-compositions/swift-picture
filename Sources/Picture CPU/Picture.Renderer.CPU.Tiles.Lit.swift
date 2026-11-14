import Picture

extension Picture.Renderer.CPU.Tiles {
    /// A sprite as it is read: its centre, its radius and its colour's pixel.
    struct Lit {
        let x: Double
        let y: Double
        let radius: Double
        let pixel: Picture.Pixel
    }
}
