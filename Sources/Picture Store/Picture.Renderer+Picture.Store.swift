#if Store
    public import File_System
    public import Picture
    import Picture_CPU

    extension Picture.Renderer {
        /// A renderer that reads a picture's pixels from a store when it holds them, and otherwise draws through
        /// `renderer` and keeps what it drew.
        ///
        /// Only a raster that holds one colour throughout before drawing, as a frame filled with its background
        /// does, is looked up and kept; any other, and a picture without a key, is drawn through as it is. What
        /// is read back is the raster `renderer` drew, bit for bit. A raster that cannot be kept is still drawn,
        /// and the store is no worse for it. The store's edition must name `renderer` and the edition of its
        /// drawing: the store cannot tell one renderer from another.
        public static func stored(in store: Picture.Store, through renderer: Picture.Renderer) -> Self {
            Self(render: { (picture: borrowing Picture, raster: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) in
                guard let ground = Picture.Store.ground(of: raster),
                    let key = store.key(picture, width: raster.width, height: raster.height, over: ground)
                else {
                    try renderer.render(picture, into: &raster)
                    return
                }
                if let kept = store.raster(for: key), kept.width == raster.width, kept.height == raster.height {
                    raster = kept
                    return
                }
                try renderer.render(picture, into: &raster)
                try? store.keep(raster, for: key)
            })
        }

        /// `cpu(threads:)` through a store in a directory whose edition is that of the CPU renderer, so pixels
        /// kept by an earlier edition of its drawing are never read back.
        public static func cpu(threads: Cardinal, storing directory: File.Directory) -> Self {
            .stored(in: .cpu(directory), through: .cpu(threads: threads))
        }
    }

    extension Picture.Store {
        /// A store in a directory for the CPU renderer of this package, at the edition of its drawing.
        public static func cpu(_ directory: File.Directory) -> Self {
            Self(directory, edition: "Picture CPU \(Picture.Renderer.CPU.edition)")
        }
    }
#endif
