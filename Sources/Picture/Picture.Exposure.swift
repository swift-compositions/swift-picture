public import Raster

extension Picture {
    /// How a picture is blurred by the travel of what shows it, a `Picture.Framing` or a scene's camera and
    /// models, while the shutter is open: `Picture.Framing.exposure(_:since:shutter:_:)` and
    /// `Picture.Scene.exposure(since:shutter:_:)`.
    public enum Exposure: Sendable, Hashable {
        /// The picture drawn at the midpoints of `samples` equal parts of the shutter and averaged: exact for
        /// every motion, at `samples` times the cost of the picture.
        case samples(Cardinal)

        /// The picture cut into `bands` by distance ahead of the eye, each band drawn once and smeared on the frame
        /// by the zoom that best carries its points from where they are seen at the end of the shutter to where
        /// they were seen at its start: about one picture and one zoom per band. A framing's picture is flat, one
        /// band.
        case bands(Cardinal)
    }
}
