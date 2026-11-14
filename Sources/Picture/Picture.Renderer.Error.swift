public import Witnesses

extension Picture.Renderer {
    /// Why a renderer did not draw a picture.
    public enum Error: Swift.Error, Sendable, Hashable {
        /// No renderer is installed.
        case absent

        /// The renderer is a placeholder made by `unimplemented()`.
        case unimplemented(Witness.Unimplemented.Error)

        /// A stroke the geometry refuses: a negative or non-finite width, or a miter limit below 1.
        case path(Picture.Plane.Path.Error)

        /// An image's drawing gave no raster for a reason of its own, which the failure carries.
        case drawing(Picture.Image.Failure)

        /// The picture holds something this renderer does not draw.
        case unsupported
    }
}

extension Picture.Renderer.Error: Witness.Unimplemented.Representable {}
