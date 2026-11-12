public import Picture
import Kernel_Thread

extension Picture.Renderer {
    /// The renderer in pure Swift on as many threads as the machine has logical processors: it draws into a
    /// copy of the raster's pixels and puts the copy in place only when the whole picture is drawn.
    public static var cpu: Self {
        cpu(threads: Cardinal(UInt(processors())))
    }

    /// The renderer in pure Swift on at most `threads` threads, the calling one among them; none counts as
    /// one. Every count gives the same raster bit for bit.
    public static func cpu(threads: Cardinal) -> Self {
        let workers = CPU.Workers(count: Swift.max(Int(bitPattern: threads), 1))
        return Self(render: { (picture: borrowing Picture, raster: inout Raster<Picture.Pixel>) throws(Picture.Renderer.Error) in
            var canvas = CPU.Canvas(raster)
            try canvas.draw(copy picture, CPU.State(transform: .identity, mask: nil, workers: workers))
            raster = canvas.raster
        })
    }
}

/// The logical processors of the machine.
private func processors() -> Int {
    Int(CPU.Logical.count)
}
