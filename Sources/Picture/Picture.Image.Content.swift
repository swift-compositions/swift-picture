public import Raster

extension Picture.Image {
    /// What an image shows: pixels it holds, or a drawing a renderer is still to draw them from.
    public enum Content: Sendable, Hashable {
        /// A raster of working pixels, its first pixel's corner at the origin of the image's own space and one unit
        /// a pixel.
        case pixels(Raster<Picture.Pixel>)

        /// A drawing the renderer that draws the image draws first, into the raster the placement puts back where
        /// the drawing stood.
        case drawing(Source)
    }
}
