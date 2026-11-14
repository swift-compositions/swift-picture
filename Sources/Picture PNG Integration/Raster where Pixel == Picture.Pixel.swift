#if PNG
    import Byte
    import IEC_61966
    public import Picture
    public import W3C_PNG

    extension Raster where Pixel == Picture.Pixel {
        public init(_ image: W3C_PNG::W3C_PNG.Image) throws(Picture.PNG.Error) {
            guard Self.sRGB(image) else { throw .encoding }
            let depth = image.bitDepth
            let channels = image.colorType.channels
            let row = image.scanlineByteCount
            let bytes = image.rawPixels
            let maximum = (1 << depth) - 1
            let linear = (0...maximum).map { Float(IEC_61966.SRGB.TransferFunction.linear(Double($0) / Double(maximum))) }
            let palette = (image.palette ?? []).map { (entry: W3C_PNG::W3C_PNG.PaletteEntry) -> Compositing.Color<Float> in
                Compositing.Color(
                    red: IEC_61966.SRGB.Level.linear(entry.r.underlying),
                    green: IEC_61966.SRGB.Level.linear(entry.g.underlying),
                    blue: IEC_61966.SRGB.Level.linear(entry.b.underlying)
                )
            }
            try self.init(
                width: Cardinal(UInt(image.width)),
                height: Cardinal(UInt(image.height))
            ) { (x: Ordinal, y: Ordinal) throws(Picture.PNG.Error) -> Picture.Pixel in
                let start = Int(bitPattern: y) * row
                let first = Int(bitPattern: x) * channels
                let sample = { (channel: Int) -> Int in
                    Self.sample(bytes, start: start, index: first + channel, depth: depth)
                }
                let alpha = { (channel: Int) -> Float in
                    Float(Double(sample(channel)) / Double(maximum))
                }
                switch image.colorType {
                case .grayscale:
                    return Self.pixel(Compositing.Color(red: linear[sample(0)], green: linear[sample(0)], blue: linear[sample(0)]), 1)

                case .grayscaleAlpha:
                    return Self.pixel(Compositing.Color(red: linear[sample(0)], green: linear[sample(0)], blue: linear[sample(0)]), alpha(1))

                case .rgb:
                    return Self.pixel(Compositing.Color(red: linear[sample(0)], green: linear[sample(1)], blue: linear[sample(2)]), 1)

                case .rgba:
                    return Self.pixel(Compositing.Color(red: linear[sample(0)], green: linear[sample(1)], blue: linear[sample(2)]), alpha(3))

                case .indexed:
                    let index = sample(0)
                    guard index < palette.count else { throw .index }
                    return Self.pixel(palette[index], 1)
                }
            }
        }

        static func sRGB(_ image: W3C_PNG::W3C_PNG.Image) -> Swift.Bool {
            if let cicp = image.cicp { return cicp == .sRGB }
            if image.sRGB != nil { return true }
            if let gamma = image.gamma { return gamma == .sRGB }
            return true
        }

        static func sample(_ bytes: [Byte], start: Int, index: Int, depth: Int) -> Int {
            switch depth {
            case 16:
                return Int(bytes[start + index * 2].underlying) << 8 | Int(bytes[start + index * 2 + 1].underlying)

            case 8:
                return Int(bytes[start + index].underlying)

            default:
                let bit = index * depth
                let shift = 8 - depth - bit % 8
                return Int(bytes[start + bit / 8].underlying) >> shift & ((1 << depth) - 1)
            }
        }

        static func pixel(_ color: Compositing.Color<Float>, _ alpha: Float) -> Picture.Pixel {
            Compositing.Premultiplied(Compositing.Straight(color: color, alpha: alpha))
        }
    }
#endif
