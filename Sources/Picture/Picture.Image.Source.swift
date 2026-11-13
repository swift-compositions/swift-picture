public import Raster

extension Picture.Image {
    /// What an image is still to be drawn from: a drawing of any type, and a hash of it made once.
    ///
    /// A source is hashed once, when it is made, from its drawing's type and value, never from pixels: every
    /// later hash of the source, however often a renderer looks it up, combines that one number. Two sources are
    /// equal when their drawings are of one type and equal; the hashes are compared first, so unequal sources are
    /// told apart without comparing their drawings. One picture holds drawings of many types, so a source keeps
    /// its drawing's type out of its own: it holds what the drawing names, how it draws, and how to compare it.
    public struct Source: Sendable {
        /// The pictures the drawing draws through the renderer it is given.
        public let pictures: [Picture]

        /// The drawing's raster, drawn now.
        let draw: @Sendable (Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel>

        /// The drawing's value.
        let value: @Sendable () -> Any

        /// Whether a value is a drawing of the same type, equal to this one.
        let same: @Sendable (Any) -> Bool

        /// The hash of the drawing's type and value, made once.
        let digest: Int

        public init<Value: Drawing>(_ drawing: Value) {
            self.pictures = drawing.pictures
            self.draw = { (renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> in
                try drawing.raster(through: renderer)
            }
            self.value = { drawing }
            self.same = { other in (other as? Value) == drawing }
            var hasher = Hasher()
            hasher.combine(ObjectIdentifier(Value.self))
            hasher.combine(drawing)
            self.digest = hasher.finalize()
        }
    }
}

extension Picture.Image.Source {
    /// The part of a picture inside a rectangle, `Picture.Image.Part(_:in:scale:samples:)`.
    public init(_ picture: Picture, in rectangle: Picture.Plane.Rectangle, scale: Double, samples: Cardinal = 1) {
        self.init(Picture.Image.Part(picture, in: rectangle, scale: scale, samples: samples))
    }

    /// The drawing, if it is of a type.
    public func drawing<Value: Picture.Image.Drawing>(as type: Value.Type) -> Value? {
        value() as? Value
    }

    /// The source drawn by a renderer: its drawing's raster.
    public func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
        try draw(renderer)
    }
}

extension Picture.Image.Source: Hashable {
    public static func == (first: Self, second: Self) -> Bool {
        first.digest == second.digest && first.same(second.value())
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(digest)
    }
}
