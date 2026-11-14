public import Picture

#if Threads
    import Kernel_Thread
#endif

extension Picture.Renderer {
    /// The renderer in pure Swift on as many threads as the machine has logical processors, with the
    /// `Threads` trait, and on one without it: it draws into a
    /// copy of the raster's pixels and puts the copy in place only when the whole picture is drawn.
    public static var cpu: Self {
        cpu(threads: Cardinal(UInt(processors())))
    }

    /// The renderer in pure Swift on at most `threads` threads, the calling one among them; none counts as
    /// one. Every count gives the same raster bit for bit. It keeps up to 2²⁵ pixels of what it draws for
    /// images that name their picture.
    public static func cpu(threads: Cardinal) -> Self {
        cpu(threads: threads, keeping: Cardinal(UInt(CPU.keeping)))
    }

    /// The renderer in pure Swift on at most `threads` threads, keeping at most `pixels` pixels of what it
    /// draws for images that name their picture, from one picture to the next, for as long as this value or
    /// a copy of it lives. A pixel is 16 bytes. With no pixels to keep, every picture draws its images afresh.
    public static func cpu(threads: Cardinal, keeping pixels: Cardinal) -> Self {
        cpu(CPU.Workers(count: Swift.max(Int(bitPattern: threads), 1)), CPU.Cache(bound: Int(clamping: pixels)))
    }

    /// The renderer on some workers that keeps what it draws for images in a store.
    static func cpu(_ workers: CPU.Workers, _ cache: CPU.Cache) -> Self {
        Self(render: { (picture: borrowing Picture, raster: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) in
            var canvas = CPU.Canvas(raster)
            try canvas.draw(try cache.resolved(copy picture, workers), CPU.State(transform: .identity, mask: nil, workers: workers))
            raster = canvas.raster
        })
    }
}

/// The logical processors of the machine, or one without the `Threads` trait.
private func processors() -> Int {
    #if Threads
        Int(CPU.Logical.count)
    #else
        1
    #endif
}
