public import Raster

extension Picture.Image {
    /// The part of a picture an image is to be drawn from: the picture, the rectangle of it to keep, how many
    /// pixels of the raster one unit of the picture takes, and how many times as fine along each side it is
    /// drawn before every pixel takes the mean of its square.
    public struct Part: Sendable, Hashable {
        public let picture: Picture
        public let rectangle: Picture.Plane.Rectangle
        public let scale: Double
        public let samples: Cardinal

        public init(_ picture: Picture, in rectangle: Picture.Plane.Rectangle, scale: Double, samples: Cardinal = 1) {
            self.picture = picture
            self.rectangle = rectangle
            self.scale = scale
            self.samples = samples
        }
    }
}

extension Picture.Image.Part {
    /// Where the raster drawn from this part stands: its first corner at the rectangle's, and one pixel at one
    /// part in `scale` of a unit.
    public var placement: Picture.Transform {
        Picture.Transform(rows: [[1 / scale, 0, rectangle.llx.underlying], [0, 1 / scale, rectangle.lly.underlying]])
    }
}

extension Picture.Image.Part: Picture.Image.Drawing {
    public var pictures: [Picture] { [picture] }

    /// The part drawn by a renderer: the picture, moved and scaled so that the rectangle's first corner is the
    /// raster's and `scale` pixels are one unit, drawn into a transparent raster of the rectangle's size in
    /// pixels, each side rounded up.
    ///
    /// It fails with `.unsupported` for a rectangle with no area and for a scale that is not positive and
    /// finite, and with the renderer's own error otherwise.
    public func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
        let left = rectangle.llx.underlying
        let top = rectangle.lly.underlying
        let across = (rectangle.urx.underlying - left) * scale
        let down = (rectangle.ury.underlying - top) * scale
        let fine = Swift.max(Int(clamping: samples), 1)
        guard scale > 0, scale.isFinite, across > 0, down > 0, across.isFinite, down.isFinite,
            across < Double(Int32.max / Int32(clamping: fine)), down < Double(Int32.max / Int32(clamping: fine))
        else { throw .unsupported }
        let width = Int(across.rounded(.up))
        let height = Int(down.rounded(.up))
        let zoom = scale * Double(fine)
        let moved = Picture.Transform(rows: [[zoom, 0, -left * zoom], [0, zoom, -top * zoom]])
        var raster = Raster<Picture.Pixel>(
            width: Cardinal(UInt(width * fine)),
            height: Cardinal(UInt(height * fine)),
            repeating: .transparent
        )
        try renderer.render([.group(Picture.Group(picture, transform: moved))], into: &raster)
        if fine > 1 {
            raster = raster.resampled(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), .box) { (from: Picture.Pixel, to: Picture.Pixel, parameter: Float) in
                from.interpolated(to: to, at: parameter)
            }
        }
        return raster
    }
}
