import Testing

@testable import Picture_Store

#if Store
    import Byte
    import File_System
    import Picture_CPU

    @Suite struct `Store Tests` {
        /// A square `size` on a side at `x`, in a colour.
        static func square(_ x: Double, _ size: Double, _ color: Picture.Color) -> Picture.Element {
            let corners: [Picture.Plane.Point<2>] = [.init([x, 1]), .init([x + size, 1]), .init([x + size, 1 + size]), .init([x, 1 + size])]
            let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
                Picture.Plane.Path.Segment.line(.init(start: start, end: end))
            }
            let path = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
            return .shape(Picture.Shape(path, fill: .init(.solid(color))))
        }

        static let picture: Picture = [square(2.5, 7.25, .black), square(9, 3, .white)]

        /// A directory of its own under the system's temporary directory.
        static func directory() throws -> File.Directory {
            File.Directory(try File.Path(validating: "/tmp/picture-store-tests-" + Swift.String(UInt64.random(in: 0...UInt64.max))))
        }

        static func key(_ store: Picture.Store, _ picture: Picture = picture, form: Swift.String = "raw") throws -> Picture.Store.Key {
            try #require(store.key(picture, width: 24, height: 16, over: .transparent, form: form))
        }

        static let payload: [Byte] = (0..<100_000).map { Byte(bitPattern: UInt8(truncatingIfNeeded: $0 &* 7)) }

        @Test func `kept bytes are read back as they were`() throws {
            let store = Picture.Store.cpu(try Self.directory())
            let key = try Self.key(store)
            #expect(store.bytes(for: key) == nil)
            try store.keep(Self.payload, for: key)
            #expect(store.bytes(for: key) == Self.payload)
            try store.keep([], for: key)
            #expect(store.bytes(for: key) == [])
        }

        @Test func `a changed picture, size, ground, form or edition is another key`() throws {
            let store = Picture.Store(try Self.directory(), edition: "one")
            let other = Picture.Store(store.directory, edition: "two")
            let moved: Picture = [Self.square(2.5, 7.25, .black), Self.square(9.0001, 3, .white)]
            let keys = [
                store.key(Self.picture, width: 24, height: 16, over: .transparent, form: "raw"),
                store.key(moved, width: 24, height: 16, over: .transparent, form: "raw"),
                store.key(Self.picture, width: 16, height: 24, over: .transparent, form: "raw"),
                store.key(Self.picture, width: 24, height: 16, over: Picture.Color.white.pixel, form: "raw"),
                store.key(Self.picture, width: 24, height: 16, over: .transparent, form: "png"),
                other.key(Self.picture, width: 24, height: 16, over: .transparent, form: "raw"),
            ]
            #expect(Set(keys.compactMap { $0 }).count == keys.count)
            #expect(keys[0] == store.key(Self.picture, width: 24, height: 16, over: .transparent, form: "raw"))
        }

        @Test func `a picture's key is of its value alone: shared and copied equal arrays give one key, one changed element another`() throws {
            let store = Picture.Store(try Self.directory(), edition: "one")
            func key(_ picture: Picture) -> Picture.Store.Key? {
                store.key(picture, width: 24, height: 16, over: .transparent, form: "raw")
            }
            let swarm = Picture.Sprites(
                (0..<40).map { index in
                    Picture.Sprites.Sprite(center: .init([Double(index), 3]), radius: 2, color: .init(red: 1, green: Float(index) / 40, blue: 0))
                }
            )
            let copied = Picture.Sprites(swarm.sprites.map { $0 }, profile: swarm.profile)
            let shared: Picture = [.sprites(swarm), .sprites(swarm)]
            let fresh: Picture = [.sprites(swarm), .sprites(copied)]
            #expect(key(shared) != nil)
            #expect(key(shared) == key(fresh))
            let inner = Picture((0..<12).map { Self.square(Double($0), 1.5, .white) })
            let again = Picture(inner.elements.map { $0 })
            let groups: Picture = [.group(.init(inner)), .group(.init(inner))]
            let copies: Picture = [.group(.init(inner)), .group(.init(again))]
            #expect(key(groups) != nil)
            #expect(key(groups) == key(copies))
            var changed = swarm.sprites
            changed[39].radius = 2.5
            #expect(key(shared) != key([.sprites(swarm), .sprites(Picture.Sprites(changed, profile: swarm.profile))]))
            let other = Picture((0..<12).map { Self.square(Double($0), $0 == 11 ? 1.25 : 1.5, .white) })
            #expect(key(groups) != key([.group(.init(inner)), .group(.init(other))]))
        }

        @Test func `a truncated, damaged or misnamed entry is a miss`() throws {
            let store = Picture.Store.cpu(try Self.directory())
            let key = try Self.key(store)
            try store.keep(Self.payload, for: key)
            let file = try #require(store.file(for: key))
            let whole = try file.read.bytes()

            try file.write.atomic(Array(whole.dropLast(5)).span)
            #expect(store.bytes(for: key) == nil)

            var damaged = whole
            damaged[Picture.Store.header + 1000] = Byte(bitPattern: damaged[Picture.Store.header + 1000].bitPattern ^ 1)
            try file.write.atomic(damaged.span)
            #expect(store.bytes(for: key) == nil)

            let other = try Self.key(store, [Self.square(1, 1, .white)])
            try #require(store.file(for: other)).write.atomic(whole.span)
            #expect(store.bytes(for: other) == nil)
        }

        @Test func `a picture with a kept image has the same key in every process`() throws {
            let inner: Picture = [Self.square(1, 3, .white)]
            let rectangle = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 8, ury: 8)
            let image = Picture.Image(inner, in: rectangle, scale: 2)
            let picture: Picture = [.fill(Picture.Plane.Path(subpaths: []), .image(image))]
            let store = Picture.Store(try Self.directory(), edition: "fixed")
            // Written by an earlier run, at the store's format 4: the image's source keeps a `Hasher` value that differs per process,
            // which its canonical value, the part it names, leaves out.
            let hex = try Self.key(store, picture).hex
            #expect(hex == "ea9a6456f6aa863c21faa206e27996f90dd9cbfd434fc885cb51faab1b4e80f3")
        }

        @Test func `processes keeping one entry at once leave one whole entry`() async throws {
            let store = Picture.Store.cpu(try Self.directory())
            let key = try Self.key(store)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<8 {
                    group.addTask { try store.keep(Self.payload, for: key) }
                }
                try await group.waitForAll()
            }
            #expect(store.bytes(for: key) == Self.payload)
        }
    }
#endif
