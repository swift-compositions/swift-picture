import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `Kept images and the recipes built on them draw the pixels recorded before images were deferred` {}
}

/// Each recipe that keeps a picture as an image, drawn on 48 × 40, against the digest of what the renderer drew
/// at the edition the edition test names.
extension `Picture CPU Tests`.`Kept images and the recipes built on them draw the pixels recorded before images were deferred` {
    static let digests: [String: UInt64] = [
        "bloom": 14_234_122_658_822_933_115, "exposure": 3_574_538_934_515_692_019, "fine": 4_439_107_359_031_923_427,
        "glow": 6_040_895_764_212_604_469, "kept": 16_933_531_291_270_939_169, "nested": 14_485_074_764_390_666_543,
        "onto": 6_240_055_181_281_504_490, "rays": 7_579_701_840_717_718_840,
    ]

    static let rectangle = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 48, ury: 40)

    /// A scene of bright and dim parts.
    static let scene: Picture = [
        `Picture CPU Tests`.fill(`Picture CPU Tests`.rectangle(0, 0, 48, 40), Picture.Color(red: 0.05, green: 0.08, blue: 0.12)),
        `Picture CPU Tests`.fill(`Picture CPU Tests`.rectangle(10.5, 8.25, 9, 7), .white),
        `Picture CPU Tests`.fill(
            `Picture CPU Tests`.polygon([`Picture CPU Tests`.at(28.3, 20.1), `Picture CPU Tests`.at(44.7, 26.2), `Picture CPU Tests`.at(31.4, 37.8)]),
            Picture.Color(red: 1, green: 0.7, blue: 0.2)
        ),
        `Picture CPU Tests`.fill(`Picture CPU Tests`.rectangle(4, 30, 14, 3), Picture.Color(red: 0.3, green: 0.4, blue: 0.9)),
    ]

    static func pictures() throws -> [String: Picture] {
        let inner = Picture([.image(scene, in: .init(llx: 8, lly: 6, urx: 22, ury: 18), scale: 1.5)])
        return [
            "kept": [.image(scene, in: rectangle, scale: 1)],
            "fine": [.image(scene, in: .init(llx: 4, lly: 4, urx: 30, ury: 30), scale: 0.75, samples: 3, edge: .mirror, filling: rectangle)],
            "onto": [
                try .image(
                    scene,
                    in: .init(llx: 0, lly: 0, urx: 24, ury: 20),
                    scale: 2,
                    onto: [`Picture CPU Tests`.at(3, 2), `Picture CPU Tests`.at(44, 6), `Picture CPU Tests`.at(40, 37), `Picture CPU Tests`.at(6, 33)]
                )
            ],
            "nested": [.image(inner.appending(scene), in: rectangle, scale: 0.5, samples: 2)],
            "bloom": scene.bloom(in: rectangle, deviation: 6, octaves: 3),
            "rays": scene.rays(from: `Picture CPU Tests`.at(24, 20), in: rectangle, length: 0.4, streaks: 3),
            "glow": scene.glow(deviation: 2.5, strength: 0.6),
            "exposure": Picture.exposure(samples: 3) { fraction in
                Picture([.group(Picture.Group([.image(scene, in: rectangle, scale: 1)], transform: Picture.Transform(rows: [[1, 0, fraction * 6], [0, 1, 0]])))])
            },
        ]
    }

    @Test
    func `Each recipe draws the pixels recorded before images were deferred, on one thread or three`() throws {
        var drawn: [String: UInt64] = [:]
        for (name, picture) in try Self.pictures() {
            var one = `Picture CPU Tests`.canvas(48, 40)
            try Picture.Renderer.cpu(threads: 1).render(picture, into: &one)
            var three = `Picture CPU Tests`.canvas(48, 40)
            try Picture.Renderer.cpu(threads: 3).render(picture, into: &three)
            #expect(one == three, "\(name) draws differently on three threads")
            drawn[name] = `Picture CPU Tests`.`The edition names the drawing: a picture of each feature draws the pixels recorded at it`.digest(one)
        }
        let changed = drawn.keys.sorted().filter { drawn[$0] != Self.digests[$0] }
        #expect(changed.isEmpty, "\(drawn.keys.sorted().map { "\"\($0)\": \(drawn[$0] ?? 0)" }.joined(separator: ", "))")
    }
}
