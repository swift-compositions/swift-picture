import Picture
import Picture_CPU
import Testing

extension `Picture CPU Tests` {
    @Suite
    struct `An image that names its picture is drawn by the renderer, and kept` {}
}

extension `Picture CPU Tests`.`An image that names its picture is drawn by the renderer, and kept` {
    typealias Tests = `Picture CPU Tests`

    static let small: Picture = [
        Tests.fill(Tests.rectangle(0, 0, 9, 7), Tests.blue),
        Tests.fill(Tests.polygon([Tests.at(1.3, 0.7), Tests.at(7.6, 2.1), Tests.at(3.2, 5.8)]), Tests.translucent),
        .layer(.init([Tests.fill(Tests.rectangle(4, 3, 3, 2), Tests.red)], effects: [.blur(.init(deviation: 0.8))])),
    ]

    static func part(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Picture.Plane.Rectangle {
        Picture.Plane.Rectangle(llx: .init(x), lly: .init(y), urx: .init(x + width), ury: .init(y + height))
    }

    static func moved(_ image: Picture.Image, _ onto: Picture.Transform) -> Picture.Image {
        var image = image
        image.placement = onto.multiplied(by: image.placement)
        return image
    }

    /// What makes an image of a part of a picture, at a scale and a number of samples, with an edge.
    typealias Make = (Picture, Picture.Plane.Rectangle, Double, Cardinal, Raster<Picture.Pixel>.Edge) throws(Picture.Renderer.Error) -> Picture.Image

    /// A frame that paints with images of pictures: one picture twice at two places, one drawn finer with its
    /// edge held, one as a stroke's paint, and one whose own picture paints with an image, inside a group and
    /// a blurred layer. `image` makes each image from its picture.
    static func frame(_ image: Make) throws(Picture.Renderer.Error) -> Picture {
        let first = try image(small, part(0, 0, 9, 7), 3, 1, .constant(.transparent))
        let fine = try image(small, part(2, 1, 5, 4), 2.5, 3, .extend)
        let inner = try image(small, part(1, 1, 6, 5), 2, 1, .constant(.transparent))
        let nesting: Picture = [
            Tests.fill(Tests.rectangle(0, 0, 9, 7), Tests.translucent),
            .shape(.init(Tests.rectangle(1, 1, 6, 5), fill: .init(.image(inner)))),
        ]
        let outer = try image(nesting, part(0, 0, 9, 7), 4, 2, .constant(.transparent))
        let pen = Picture.Plane.Path.Stroke(width: 5, join: .round, cap: .round)
        return [
            Tests.fill(Tests.rectangle(0, 0, 80, 60), Picture.Color(gray: 0.2)),
            .shape(.init(Tests.rectangle(2, 2, 30, 24), fill: .init(.image(moved(first, .init(rows: [[3, 0, 2], [0, 3, 2]])))))),
            .shape(.init(Tests.rectangle(40, 4, 36, 20), fill: .init(.image(moved(first, .init(rows: [[2, 0.5, 40], [-0.5, 2, 8]])))))),
            .shape(.init(Tests.rectangle(4, 30, 40, 26), fill: .init(.image(moved(fine, .init(rows: [[5, 0, 0], [0, 5, 28]])))))),
            .shape(.init(Tests.rectangle(48, 30, 26, 22), stroke: .init(.image(moved(first, .init(rows: [[4, 0, 44], [0, 4, 28]]))), pen: pen))),
            .group(
                .init(
                    [.layer(.init([.shape(.init(Tests.rectangle(0, 0, 9, 7), fill: .init(.image(outer))))], effects: [.blur(.init(deviation: 0.3))], opacity: 0.8))],
                    transform: .init(rows: [[4, 0, 30], [0, 4, 20]])
                )
            ),
        ]
    }

    @Test
    func `A frame of named images is the frame of images drawn beforehand, bit for bit, on any threads, kept or not, the first time and again`() throws {
        let plain = Picture.Renderer.cpu(threads: 1, keeping: 0)
        let eager = try Self.frame { picture, rectangle, scale, samples, edge throws(Picture.Renderer.Error) in
            try Picture.Image(picture, in: rectangle, scale: scale, samples: samples, edge: edge, through: plain)
        }
        let named = try Self.frame { picture, rectangle, scale, samples, edge in
            Picture.Image(picture, in: rectangle, scale: scale, samples: samples, edge: edge)
        }
        #expect(named != eager)
        var expected = Tests.canvas(80, 60)
        try plain.render(eager, into: &expected)
        #expect(expected != Tests.canvas(80, 60))
        let renderers: [Picture.Renderer] = [
            .cpu(threads: 1), .cpu(threads: 4), .cpu(threads: 4, keeping: 0), .cpu(threads: 3, keeping: 700), .cpu(threads: 9, keeping: 1_048_576),
        ]
        for renderer in renderers {
            for _ in 0..<3 {
                var raster = Tests.canvas(80, 60)
                try renderer.render(named, into: &raster)
                #expect(raster == expected)
            }
        }
    }

    @Test
    func `A named image that cannot be drawn fails the frame and leaves the raster as it was`() {
        let empty = Picture.Image(Self.small, in: Self.part(0, 0, 0, 7), scale: 1)
        let picture: Picture = [
            Tests.fill(Tests.rectangle(0, 0, 9, 7), Tests.red),
            .shape(.init(Tests.rectangle(0, 0, 9, 7), fill: .init(.image(Picture.Image(Self.small, in: Self.part(0, 0, 9, 7), scale: 1))))),
            .shape(.init(Tests.rectangle(0, 0, 9, 7), fill: .init(.image(empty)))),
        ]
        for threads: Cardinal in [1, 4] {
            var raster = Tests.canvas(9, 7, Tests.blue.pixel)
            #expect(throws: Picture.Renderer.Error.unsupported) {
                try Picture.Renderer.cpu(threads: threads).render(picture, into: &raster)
            }
            #expect(raster == Tests.canvas(9, 7, Tests.blue.pixel))
        }
    }
}
