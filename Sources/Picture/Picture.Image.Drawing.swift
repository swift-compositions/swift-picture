extension Picture.Image {
    /// A value that knows how to draw a raster, and is the source an image is still to be drawn from: the part
    /// of a picture (`Picture.Image.Part`), or anything else that is described cheaply and drawn dearly, such as
    /// light added up from many motes.
    ///
    /// The renderer that draws a picture holding an image with such a source draws it when it first needs it,
    /// once for every equal source, on any thread, and may keep the raster for the next picture that holds an
    /// equal source. So the value is the drawing's identity: equal values must draw the same raster, and two
    /// images are equal, hash alike and are kept under one key exactly when their drawings are equal.
    public protocol Drawing: Sendable, Hashable {
        /// The pictures the drawing draws through the renderer it is given, whose own kept images the renderer
        /// draws first; none by default.
        var pictures: [Picture] { get }

        /// The raster, drawn now; a renderer's failure is the drawing's.
        func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel>
    }
}

extension Picture.Image.Drawing {
    public var pictures: [Picture] { [] }
}
