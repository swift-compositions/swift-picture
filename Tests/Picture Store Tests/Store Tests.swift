@testable import Picture_Store
import Testing

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

        static func drawn(_ picture: Picture, through renderer: Picture.Renderer, ground: Picture.Pixel = .transparent) throws -> Raster<Picture.Pixel> {
            var raster = Raster<Picture.Pixel>(width: 24, height: 16, repeating: ground)
            try renderer.render(picture, into: &raster)
            return raster
        }

        /// The one entry in a store's directory.
        static func entry(_ store: Picture.Store, _ picture: Picture, ground: Picture.Pixel = .transparent) throws -> File {
            let key = try #require(store.key(picture, width: 24, height: 16, over: ground))
            return try #require(store.file(for: key))
        }

        @Test func `a warm store gives the pixels drawing gives, bit for bit, without drawing`() throws {
            let store = Picture.Store.cpu(try Self.directory())
            let plain = try Self.drawn(Self.picture, through: .cpu(threads: 1))
            let cold = try Self.drawn(Self.picture, through: .stored(in: store, through: .cpu(threads: 1)))
            #expect(try Self.entry(store, Self.picture).read.bytes().count > 0)
            let warm = try Self.drawn(Self.picture, through: .stored(in: store, through: .absent))
            #expect(cold == plain)
            #expect(warm == plain)
        }

        @Test func `a changed picture, size, ground or edition is another key`() throws {
            let store = Picture.Store(try Self.directory(), edition: "one")
            let other = Picture.Store(store.directory, edition: "two")
            let moved: Picture = [Self.square(2.5, 7.25, .black), Self.square(9.0001, 3, .white)]
            let keys = [
                store.key(Self.picture, width: 24, height: 16, over: .transparent),
                store.key(moved, width: 24, height: 16, over: .transparent),
                store.key(Self.picture, width: 16, height: 24, over: .transparent),
                store.key(Self.picture, width: 24, height: 16, over: Picture.Color.white.pixel),
                other.key(Self.picture, width: 24, height: 16, over: .transparent),
            ]
            #expect(Set(keys.compactMap { $0 }).count == keys.count)
            #expect(keys[0] == store.key(Self.picture, width: 24, height: 16, over: .transparent))
        }

        @Test func `a changed picture misses and is drawn`() throws {
            let store = Picture.Store.cpu(try Self.directory())
            let renderer = Picture.Renderer.stored(in: store, through: .cpu(threads: 1))
            _ = try Self.drawn(Self.picture, through: renderer)
            let moved: Picture = [Self.square(3, 7.25, .black)]
            #expect(try Self.drawn(moved, through: renderer) == Self.drawn(moved, through: .cpu(threads: 1)))
            #expect(throws: Picture.Renderer.Error.self) {
                try Self.drawn([Self.square(4, 7.25, .black)], through: .stored(in: store, through: .absent))
            }
        }

        @Test func `a truncated, damaged or misnamed entry is a miss, and is drawn and kept again`() throws {
            let store = Picture.Store.cpu(try Self.directory())
            let renderer = Picture.Renderer.stored(in: store, through: .cpu(threads: 1))
            let plain = try Self.drawn(Self.picture, through: .cpu(threads: 1))
            _ = try Self.drawn(Self.picture, through: renderer)
            let entry = try Self.entry(store, Self.picture)
            let whole = try entry.read.bytes()
            let key = try #require(store.key(Self.picture, width: 24, height: 16, over: .transparent))

            try entry.write.atomic(Array(whole.dropLast(5)).span)
            #expect(store.raster(for: key) == nil)
            #expect(try Self.drawn(Self.picture, through: renderer) == plain)
            #expect(try entry.read.bytes() == whole)

            var damaged = whole
            damaged[Picture.Store.header + 100] = Byte(bitPattern: damaged[Picture.Store.header + 100].bitPattern ^ 1)
            try entry.write.atomic(damaged.span)
            #expect(store.raster(for: key) == nil)
            #expect(try Self.drawn(Self.picture, through: renderer) == plain)

            let other = try #require(store.key([Self.square(1, 1, .white)], width: 24, height: 16, over: .transparent))
            try #require(store.file(for: other)).write.atomic(whole.span)
            #expect(store.raster(for: other) == nil)
            #expect(store.raster(for: key) == plain)
        }

        @Test func `a raster of more than one colour is drawn through and nothing is kept`() throws {
            let directory = try Self.directory()
            let store = Picture.Store.cpu(directory)
            var raster = Raster<Picture.Pixel>(width: 24, height: 16, repeating: .transparent)
            raster[x: 3, y: 3] = Picture.Color.white.pixel
            var plain = raster
            try Picture.Renderer.cpu(threads: 1).render(Self.picture, into: &plain)
            try Picture.Renderer.stored(in: store, through: .cpu(threads: 1)).render(Self.picture, into: &raster)
            #expect(raster == plain)
            #expect(!directory.stat.exists)
        }

        @Test func `processes drawing into one directory at once leave one whole entry`() async throws {
            let store = Picture.Store.cpu(try Self.directory())
            let plain = try Self.drawn(Self.picture, through: .cpu(threads: 1))
            let drawn = try await withThrowingTaskGroup(of: Raster<Picture.Pixel>.self) { group in
                for _ in 0..<8 {
                    group.addTask { try Self.drawn(Self.picture, through: .cpu(threads: 1, storing: store.directory)) }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }
            #expect(drawn.allSatisfy { $0 == plain })
            let key = try #require(store.key(Self.picture, width: 24, height: 16, over: .transparent))
            #expect(store.raster(for: key) == plain)
        }
    }
#endif
