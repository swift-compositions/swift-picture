#if Store
    public import File_System
    public import Picture

    extension Picture {
        /// Drawn pictures kept in a directory, each under a key made from what decides its pixels: the picture,
        /// the raster's size and the one colour it held before drawing, and the edition of the renderer that drew
        /// it. A picture is a value, so the same key is the same pixels, and a later run can read them back
        /// instead of drawing.
        ///
        /// Each raster is a file of its own, named by its key, written under a temporary name and renamed into
        /// place, so processes may draw into one directory at once and a reader sees a whole entry or none. An
        /// entry carries its own digest, and one that is missing, cut short, damaged or of another key is a
        /// miss, never an error.
        public struct Store: Sendable {
            /// Where the rasters are kept; made when the first is kept.
            public let directory: File.Directory

            /// The renderer and its edition, as part of every key: a renderer whose drawing changes must name
            /// another edition, or the store gives its old pixels.
            public let edition: Swift.String

            public init(_ directory: File.Directory, edition: Swift.String) {
                self.directory = directory
                self.edition = edition
            }
        }
    }
#endif
