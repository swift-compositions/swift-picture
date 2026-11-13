#if Store
    public import File_System
    public import Picture

    extension Picture.Store {
        /// Why a raster was not kept.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The directory could not be made.
            case directory(File.System.Create.Directory.Error)

            /// The entry could not be written.
            case write(File.System.Write.Atomic.Error)
        }
    }
#endif
