#if PNG
    import Byte
    import IEC_61966
    public import Picture
    public import W3C_PNG

    extension W3C_PNG::W3C_PNG.Image {
        /// A raster of working pixels as an 8-bit sRGB image with straight alpha, marked as sRGB.
        public init(_ raster: Raster<Picture.Pixel>) throws(W3C_PNG::W3C_PNG.Image.Error) {
            var bytes: [Byte] = []
            bytes.reserveCapacity(raster.pixels.count * 4)
            for pixel in raster.pixels {
                let straight = Compositing.Straight(pixel)
                bytes.append(Self.level(IEC_61966.SRGB.TransferFunction.encoded(Self.unit(straight.color.red))))
                bytes.append(Self.level(IEC_61966.SRGB.TransferFunction.encoded(Self.unit(straight.color.green))))
                bytes.append(Self.level(IEC_61966.SRGB.TransferFunction.encoded(Self.unit(straight.color.blue))))
                bytes.append(Self.level(straight.alpha))
            }
            try self.init(
                width: Int(clamping: raster.width),
                height: Int(clamping: raster.height),
                colorType: .rgba,
                bitDepth: 8,
                rawPixels: bytes,
                sRGB: .perceptual,
                gamma: .sRGB
            )
        }

        /// A component held to 0…1, with anything that is not a number as 0.
        static func unit(_ value: Float) -> Float {
            value > 0 ? Swift.min(value, 1) : 0
        }

        /// A component as one of 256 levels: held to 0…1, times 255, rounded to the nearest, halves up.
        static func level(_ value: Float) -> Byte {
            Byte(UInt8((unit(value) * 255 + 0.5).rounded(.down)))
        }
    }
#endif
