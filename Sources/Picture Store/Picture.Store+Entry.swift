#if Store
    public import Byte
    import FIPS_180_4
    import File_System
    public import Picture
    import Picture_CPU
    import RFC_1950
    import Standard_Library_Extensions

    extension Picture.Store {
        /// The key of what is made in `form` of a picture drawn into a raster of a size that holds one colour
        /// throughout before drawing, or nil when `Swift.Mirror.bytes(of:)` cannot write the picture whole, so that
        /// it is never kept.
        ///
        /// The key is the SHA-256 of, in this order: the store's format, its edition, the form, the width and the
        /// height, the memory of the colour, and the picture's bytes, fed to the digest as they are written.
        public func key(
            _ picture: borrowing Picture,
            width: Cardinal,
            height: Cardinal,
            over ground: Picture.Pixel,
            form: Swift.String
        ) -> Key? {
            var head: [UInt8] = Array("Picture.Store \(Self.format)\n".utf8)
            for text in [edition, form] {
                Self.number(UInt64(text.utf8.count), into: &head)
                head.append(contentsOf: text.utf8)
            }
            Self.number(UInt64(Int(clamping: width)), into: &head)
            Self.number(UInt64(Int(clamping: height)), into: &head)
            withUnsafeBytes(of: ground) { unsafe head.append(contentsOf: $0) }
            var hasher = FIPS_180_4.SHA256.Hasher()
            hasher.update(head.span.bytes)
            let whole = Swift.Mirror.bytes(of: copy picture) { piece in hasher.update(piece) }
            return whole ? Key(digest: hasher.finalize()) : nil
        }

        /// The bytes kept under a key, or nil when there are none, or the entry is cut short, damaged or of another
        /// key.
        public func bytes(for key: Key) -> [Byte]? {
            guard let file = file(for: key), let entry = try? file.read.bytes() else { return nil }
            return Self.payload(entry, key: key)
        }

        /// Keeps bytes under a key, replacing what was there: written whole under a temporary name, then renamed
        /// into place, without waiting for the disk.
        public func keep(_ bytes: [Byte], for key: Key) throws(Error) {
            guard let file = file(for: key) else { return }
            do throws(File.System.Create.Directory.Error) {
                try directory.create.recursive()
            } catch {
                throw .directory(error)
            }
            let entry = Self.entry(bytes, key: key)
            do throws(File.System.Write.Atomic.Error) {
                try file.write.atomic(entry.span, options: .init(durability: .none))
            } catch {
                throw .write(error)
            }
        }

        /// The entry's file: its key in hex.
        func file(for key: Key) -> File? {
            guard let name = try? File.Path.Component(key.hex + ".entry") else { return nil }
            return directory[name]
        }
    }

    extension Picture.Store {
        /// The store's format, which keys and entries begin with: raised whenever what a key is made of changes, so
        /// entries kept under an earlier format are simply missed. 4 since a glass is a skin or a body, an image
        /// pixels or a drawing, and their names and shapes changed.
        static let format: UInt64 = 4

        /// The start of every entry.
        static let magic: [UInt8] = Array("PICSTORE".utf8)

        /// The bytes before the payload: the magic, the format, the key, the payload's length and its Adler-32.
        static let header = 8 + 8 + 32 + 8 + 8

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

        /// An entry: the header, then the payload.
        static func entry(_ payload: [Byte], key: Key) -> [Byte] {
            var head: [UInt8] = magic
            number(format, into: &head)
            head.append(contentsOf: key.digest.bytes.map(\.bitPattern))
            number(UInt64(payload.count), into: &head)
            number(UInt64(RFC_1950.Adler32.checksum(payload)), into: &head)
            var entry = head.map(Byte.init(bitPattern:))
            entry.reserveCapacity(head.count + payload.count)
            entry.append(contentsOf: payload)
            return entry
        }

        /// The payload of an entry, or nil when it is not a whole entry of this key.
        static func payload(_ entry: [Byte], key: Key) -> [Byte]? {
            guard entry.count >= header,
                entry[0..<8].map(\.bitPattern) == magic,
                number(entry, at: 8) == format,
                Array(entry[16..<48]) == key.digest.bytes,
                number(entry, at: 48) == UInt64(entry.count - header)
            else { return nil }
            let payload = Array(entry[header...])
            guard number(entry, at: 56) == UInt64(RFC_1950.Adler32.checksum(payload)) else { return nil }
            return payload
        }
    }
#endif
