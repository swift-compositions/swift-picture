#if Store
    public import FIPS_180_4
    public import Picture

    extension Picture.Store {
        /// What decides a drawn raster's pixels, as a SHA-256 digest.
        public struct Key: Sendable, Hashable {
            public let digest: FIPS_180_4.Digest

            public init(digest: FIPS_180_4.Digest) {
                self.digest = digest
            }

            /// The digest in lowercase hex, the entry's file name.
            public var hex: Swift.String { digest.hex }
        }
    }
#endif
