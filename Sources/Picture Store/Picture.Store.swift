#if Store
    public import File_System
    public import Picture
    import Picture_CPU

    extension Picture {
        /// What was made of drawn pictures, kept in a directory under a key of what decides it: the picture, the
        /// raster's size and the colour it held before drawing, the edition of the renderer that drew it, and the
        /// form the caller made of the drawn raster, such as a PNG or a frame's 8-bit pixels. A picture is a value,
        /// so the same key is the same bytes, and a later run can read them back instead of drawing.
        ///
        /// Each entry is a file of its own, named by its key, written under a temporary name and renamed into
        /// place, so processes may keep entries in one directory at once and a reader sees a whole entry or none.
        /// An entry carries its length and the Adler-32 of its bytes, and one that is missing, cut short, damaged
        /// or of another key is a miss, never an error.
        public struct Store: Sendable {
            /// Where the entries are kept; made when the first is kept.
            public let directory: File.Directory

            /// The renderer and its edition, as part of every key: a renderer whose drawing changes must name
            /// another edition, or the store gives back what the old one drew.
            public let edition: Swift.String

            public init(_ directory: File.Directory, edition: Swift.String) {
                self.directory = directory
                self.edition = edition
            }
        }
    }

    extension Picture.Store {
        /// A store in a directory for pictures drawn by `Picture.Renderer.cpu` of this package, at the edition of
        /// its drawing.
        public static func cpu(_ directory: File.Directory) -> Self {
            Self(directory, edition: "Picture CPU \(Picture.Renderer.CPU.edition)")
        }
    }
#endif
