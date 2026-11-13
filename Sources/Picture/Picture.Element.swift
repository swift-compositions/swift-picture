public import Direction

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
