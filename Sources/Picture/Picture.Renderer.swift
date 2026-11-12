public import Raster
public import Renderer
public import W3C_CSS_Compositing
public import Witnesses

extension Picture {
    /// The operation that draws a picture into a raster of working pixels, as a value that can be replaced.
    @Witness
    public struct Renderer: Sendable {
        public var render: @Sendable (_ picture: borrowing Picture, _ raster: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) -> Void
    }
}

extension Picture.Renderer {
    /// The renderer that draws nothing and fails with `.absent`.
    public static var absent: Self {
        Self(render: { (_: borrowing Picture, _: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) in
            throw .absent
        })
    }
}

extension Picture.Renderer: Renderer::Renderer.`Protocol` {
    public typealias Input = Picture
    public typealias Context = Raster<Picture.Pixel>
    public typealias Failure = Picture.Renderer.Error

    public borrowing func render(_ input: borrowing Picture, into context: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) {
        try self.render(input, &context)
    }
}
