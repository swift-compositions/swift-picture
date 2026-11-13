#if Store
    public import Byte
    import FIPS_180_4
    import File_System
    public import Picture
    import Standard_Library_Extensions

    extension Picture.Store {
        /// The key of a picture drawn into a raster of a size that holds one colour throughout, or nil when the
        /// picture's structure cannot be written whole by `Swift.Mirror.bytes(of:)`, so that it is never kept.
        ///
        /// The key covers, in this order: the store's format, its edition, the width and the height, the memory
        /// of the colour, and the picture's bytes.
        public func key(
            _ picture: borrowing Picture,
            width: Cardinal,
            height: Cardinal,
            over ground: Picture.Pixel
        ) -> Key? {
            guard let structure = Swift.Mirror.bytes(of: copy picture) else { return nil }
            var bytes: [UInt8] = Array("Picture.Store 1\n".utf8)
            Self.number(UInt64(edition.utf8.count), into: &bytes)
            bytes.append(contentsOf: edition.utf8)
            Self.number(UInt64(Int(clamping: width)), into: &bytes)
            Self.number(UInt64(Int(clamping: height)), into: &bytes)
            withUnsafeBytes(of: ground) { unsafe bytes.append(contentsOf: $0) }
            bytes.append(contentsOf: structure)
            return Key(digest: FIPS_180_4.SHA256.digest(bytes.map(Byte.init(bitPattern:))))
        }

        /// The raster kept under a key, or nil when there is none, or the entry is cut short, damaged, of another
        /// key or of another kind of pixel.
        public func raster(for key: Key) -> Raster<Picture.Pixel>? {
            guard let file = file(for: key), let bytes = try? file.read.bytes() else { return nil }
            return Self.raster(bytes, key: key)
        }

        /// Keeps a raster under a key, replacing what was there: written whole under a temporary name, then
        /// renamed into place, without waiting for the disk.
        public func keep(_ raster: Raster<Picture.Pixel>, for key: Key) throws(Error) {
            guard let file = file(for: key) else { return }
            do throws(File.System.Create.Directory.Error) {
                try directory.create.recursive()
            } catch {
                throw .directory(error)
            }
            let bytes = Self.entry(raster, key: key)
            do throws(File.System.Write.Atomic.Error) {
                try file.write.atomic(bytes.span, options: .init(durability: .none))
            } catch {
                throw .write(error)
            }
        }

        /// The entry's file: its key in hex with `.raster`.
        func file(for key: Key) -> File? {
            guard let name = try? File.Path.Component(utf8: (key.hex + ".raster").utf8) else { return nil }
            return directory[name]
        }
    }

    extension Picture.Store {
        /// The start of every entry.
        static let magic: [UInt8] = Array("PICSTORE".utf8)

        /// The bytes before the pixels: the magic, the format, the pixel's size, the width, the height and the key.
        static let header = 8 + 8 + 8 + 8 + 8 + 32

        static func number(_ value: UInt64, into bytes: inout [UInt8]) {
            withUnsafeBytes(of: value.littleEndian) { unsafe bytes.append(contentsOf: $0) }
        }

        static func number(_ bytes: [Byte], at offset: Int) -> UInt64 {
            var value: UInt64 = 0
            for index in (0..<8).reversed() {
                value = value << 8 | UInt64(bytes[offset + index].bitPattern)
            }
            return value
        }

        /// An entry: the header, the pixels' memory, and the SHA-256 of both.
        static func entry(_ raster: Raster<Picture.Pixel>, key: Key) -> [Byte] {
            var head: [UInt8] = magic
            number(1, into: &head)
            number(UInt64(MemoryLayout<Picture.Pixel>.stride), into: &head)
            number(UInt64(Int(clamping: raster.width)), into: &head)
            number(UInt64(Int(clamping: raster.height)), into: &head)
            head.append(contentsOf: key.digest.bytes.map(\.bitPattern))
            let pixels = raster.pixels
            let size = pixels.count * MemoryLayout<Picture.Pixel>.stride
            var bytes = [Byte](repeating: Byte(bitPattern: 0), count: head.count + size)
            bytes.withUnsafeMutableBytes { target in
                head.withUnsafeBytes { unsafe target.copyMemory(from: $0) }
                pixels.withUnsafeBytes { source in
                    unsafe UnsafeMutableRawBufferPointer(rebasing: target[head.count...]).copyMemory(from: source)
                }
            }
            bytes.append(contentsOf: FIPS_180_4.SHA256.digest(bytes).bytes)
            return bytes
        }

        /// The raster of an entry, or nil when it is not a whole entry of this key and this pixel.
        static func raster(_ bytes: [Byte], key: Key) -> Raster<Picture.Pixel>? {
            let stride = MemoryLayout<Picture.Pixel>.stride
            guard bytes.count >= header + 32,
                Array(bytes[0..<8].map(\.bitPattern)) == magic,
                number(bytes, at: 8) == 1,
                number(bytes, at: 16) == UInt64(stride),
                Array(bytes[40..<72]) == key.digest.bytes
            else { return nil }
            let width = number(bytes, at: 24)
            let height = number(bytes, at: 32)
            let (count, overflow) = width.multipliedReportingOverflow(by: height)
            guard !overflow, count <= UInt64(Int.max / stride),
                bytes.count == header + Int(count) * stride + 32
            else { return nil }
            let body = bytes.count - 32
            guard FIPS_180_4.SHA256.digest(Array(bytes[..<body])).bytes == Array(bytes[body...]) else { return nil }
            let pixels = unsafe [Picture.Pixel](unsafeUninitializedCapacity: Int(count)) { buffer, initialized in
                bytes.withUnsafeBytes { source in
                    unsafe UnsafeMutableRawBufferPointer(buffer).copyMemory(
                        from: UnsafeRawBufferPointer(rebasing: source[header..<body])
                    )
                }
                initialized = Int(count)
            }
            return try? Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), pixels: pixels)
        }

        /// The one colour a raster holds throughout, bit for bit, or nil when it holds more than one or none.
        static func ground(of raster: Raster<Picture.Pixel>) -> Picture.Pixel? {
            let pixels = raster.pixels
            guard let first = pixels.first else { return nil }
            let stride = MemoryLayout<Picture.Pixel>.stride
            let same = pixels.withUnsafeBytes { memory in
                var offset = stride
                while offset < memory.count {
                    for word in Swift.stride(from: 0, to: stride, by: 8) {
                        let one = unsafe memory.loadUnaligned(fromByteOffset: word, as: UInt64.self)
                        let other = unsafe memory.loadUnaligned(fromByteOffset: offset + word, as: UInt64.self)
                        guard one == other else { return false }
                    }
                    offset += stride
                }
                return true
            }
            return same ? first : nil
        }
    }
#endif
