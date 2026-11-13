public import Direction
public import Matrix
public import Raster
import Vector

extension Picture {
    /// One thing a picture draws.
    public indirect enum Element: Sendable, Hashable {
        /// A path, filled, stroked or both.
        case shape(Shape)

        /// Round sprites that add their light to what is behind them.
        case sprites(Sprites)

        /// Meshes seen through a camera.
        case scene(Scene)

        /// A picture moved by a transform and limited to a clip, drawn straight onto what is behind.
        case group(Group)

        /// A picture drawn on its own, changed by effects, and then put onto what is behind as one.
        case layer(Layer)

        /// A flat pane of glass over what is behind it.
        case pane(Glass.Pane)
    }
}

extension Picture.Element {
    /// A path filled with a paint under a rule: a shape with a fill and no stroke.
    public static func fill(_ path: Picture.Plane.Path, _ paint: Picture.Paint, rule: Winding.Rule = .nonzero) -> Self {
        .shape(Picture.Shape(path, fill: Picture.Shape.Fill(paint, rule: rule)))
    }

    /// A pen line along a path in a paint: a shape with a stroke and no fill.
    public static func stroke(_ path: Picture.Plane.Path, _ paint: Picture.Paint, pen: Picture.Plane.Path.Stroke) -> Self {
        .shape(Picture.Shape(path, stroke: Picture.Shape.Stroke(paint, pen: pen)))
    }

    /// A pen line along a path in a paint, with a pen of a width, a join and a cap.
    public static func stroke(
        _ path: Picture.Plane.Path,
        _ paint: Picture.Paint,
        width: Double,
        join: Picture.Plane.Path.Stroke.Join,
        cap: Picture.Plane.Path.Stroke.Cap
    ) -> Self {
        stroke(path, paint, pen: Picture.Plane.Path.Stroke(width: .init(width), join: join, cap: cap))
    }
}

extension Picture.Element {
    /// A glow of a colour around a centre: the square around the circle of the radius, filled with
    /// `Picture.Paint.glow(_:center:radius:core:)`, which is clear outside the circle. Over what is behind it
    /// puts its colour as far as the falloff lets it; in a layer under `lighter` it adds its light.
    public static func glow(
        _ color: Picture.Color,
        center: Picture.Plane.Point<2>,
        radius: Double,
        core: Double = 0.25
    ) -> Self {
        let (x, y) = (center[0], center[1])
        let corners: [Picture.Plane.Point<2>] = [
            .init([x - radius, y - radius]), .init([x + radius, y - radius]),
            .init([x + radius, y + radius]), .init([x - radius, y + radius]),
        ]
        let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
            Picture.Plane.Path.Segment.line(.init(start: start, end: end))
        }
        let square = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
        return .fill(square, .glow(color, center: center, radius: radius, core: core))
    }
}

extension Picture.Element {
    /// The part of a picture inside a rectangle kept as an image, standing where that part stood: an area filled
    /// with `Picture.Image(_:in:scale:samples:sampling:edge:)` of it. The renderer draws the part once, at
    /// `scale` pixels to a unit, and paints it back as an image, so it can be shown again, moved and repeated for
    /// the price of an image, and a part that does not change from frame to frame is drawn once for all of them.
    /// The area is the rectangle by default; a wider one shows the image's `edge` beyond the rectangle, so an
    /// edge of `.mirror` fills it with the part mirrored, `.wrap` with the part repeated and `.extend` with its
    /// border pixels drawn out.
    public static func image(
        _ picture: Picture,
        in rectangle: Picture.Plane.Rectangle,
        scale: Double,
        samples: Cardinal = 1,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent),
        filling area: Picture.Plane.Rectangle? = nil
    ) -> Self {
        let image = Picture.Image(picture, in: rectangle, scale: scale, samples: samples, sampling: sampling, edge: edge)
        return .fill(Picture.area(area ?? rectangle), .image(image))
    }

    /// The part of a picture inside a rectangle kept as an image, as `image(_:in:scale:samples:sampling:edge:filling:)`
    /// keeps it, and fitted onto four corners in perspective: the quadrilateral of the corners filled with the
    /// image under the projective map that takes the rectangle's corners, (llx, lly), (urx, lly), (urx, ury) and
    /// (llx, ury) in that order, onto them, `Matrix<3, 3, Double>(fitting:onto:)` of swift-matrix. So the part is
    /// a card seen at a slant, straight lines kept straight and nearer parts larger, read perspective-correct at
    /// every pixel. A rectangle with no area and corners three of which lie on one line fit no map and fail with
    /// `Matrix.Error.singular`.
    public static func image(
        _ picture: Picture,
        in rectangle: Picture.Plane.Rectangle,
        scale: Double,
        samples: Cardinal = 1,
        sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
        edge: Raster<Picture.Pixel>.Edge = .constant(.transparent),
        onto corners: InlineArray<4, Picture.Plane.Point<2>>
    ) throws(Matrix<3, 3, Double>.Error) -> Self {
        let (left, top) = (rectangle.llx.underlying, rectangle.lly.underlying)
        let (right, bottom) = (rectangle.urx.underlying, rectangle.ury.underlying)
        let sources: InlineArray<4, Vector<2, Double>> = [Vector([left, top]), Vector([right, top]), Vector([right, bottom]), Vector([left, bottom])]
        let targets: InlineArray<4, Vector<2, Double>> = [
            Vector([corners[0][0], corners[0][1]]), Vector([corners[1][0], corners[1][1]]),
            Vector([corners[2][0], corners[2][1]]), Vector([corners[3][0], corners[3][1]]),
        ]
        let fit = try Matrix<3, 3, Double>(fitting: sources, onto: targets)
        var image = Picture.Image(picture, in: rectangle, scale: scale, samples: samples, sampling: sampling, edge: edge)
        image.placement = fit.multiplied(by: image.placement)
        let quadrilateral = Picture.Plane.Path([Picture.Plane.Polygon(vertices: [corners[0], corners[1], corners[2], corners[3]])])
        return .fill(quadrilateral, .image(image))
    }
}
