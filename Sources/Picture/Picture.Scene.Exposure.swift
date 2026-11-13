public import Raster

extension Picture.Scene {
    /// How a scene is blurred by its camera's travel while the shutter is open.
    public enum Exposure: Sendable, Hashable {
        /// The scene drawn at the midpoints of `samples` equal parts of the shutter and averaged: exact for
        /// every motion, at `samples` times the cost of the scene.
        case samples(Cardinal)

        /// The models cut into `bands` by their distance ahead of the eye, each band drawn once and smeared on
        /// the frame by the zoom that best carries its points from where they are seen at the end of the shutter
        /// to where they were seen at its start: about one scene and one zoom per band.
        case bands(Cardinal)
    }
}
