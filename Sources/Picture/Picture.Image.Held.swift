import Raster
import Synchronization

extension Picture.Image {
    /// An image's raster, and the hash of its pixels, made the first time it is asked for and kept for every
    /// copy of the image.
    final class Held: Sendable {
        let raster: Raster<Picture.Pixel>
        let digest: Mutex<Int?>

        init(_ raster: Raster<Picture.Pixel>) {
            self.raster = raster
            self.digest = Mutex(nil)
        }
    }
}

extension Picture.Image.Held {
    /// The hash of the raster.
    var hash: Int {
        digest.withLock { digest in
            if let digest { return digest }
            var hasher = Hasher()
            hasher.combine(raster)
            let made = hasher.finalize()
            digest = made
            return made
        }
    }
}
