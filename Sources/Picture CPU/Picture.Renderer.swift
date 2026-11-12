public import Picture

extension Picture.Renderer {
    /// The renderer in pure Swift: it draws on one thread, into a copy of the raster's pixels,
    /// and puts the copy in place only when the whole picture is drawn.
    public static var cpu: Self {
        Self(render: { (picture: borrowing Picture, raster: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) in
            var canvas = CPU.Canvas(raster)
            try canvas.draw(copy picture, CPU.State(transform: .identity, mask: nil))
            raster = canvas.raster
        })
    }
}

extension Picture.Renderer: Witness.Key {
    public static var liveValue: Self { .cpu }
}
