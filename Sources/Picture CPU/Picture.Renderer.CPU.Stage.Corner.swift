import Picture

extension Picture.Renderer.CPU.Stage {
    /// A corner of a face of a model, before projection: where it is, how far in front of the near plane,
    /// its normal and its fourth clip coordinate.
    struct Corner {
        var point: Point<3, Double>
        var distance: Double
        var normal: Vector<3, Double>
        var divisor: Double
    }
}
