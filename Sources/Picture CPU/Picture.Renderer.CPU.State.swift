import Picture

extension Picture.Renderer.CPU {
    /// Where an element draws: the transform from its space into raster space, and the clips around it.
    struct State {
        var transform: Picture.Transform
        var mask: Mask?
        var workers: Workers = .one
    }
}

extension Picture.Renderer.CPU.State {
    /// The transform from raster space back into the element's space, or nil when it squashes the plane.
    var inverse: Picture.Transform? {
        do throws(Matrix<2, 3, Double>.Error) {
            return try transform.inverted()
        } catch {
            return nil
        }
    }

    /// The pixels the element may change in a canvas of a box.
    func reach(in box: Picture.Renderer.CPU.Box) -> Picture.Renderer.CPU.Box {
        guard let mask else { return box }
        return box.intersection(mask.box)
    }

    /// The share of a pixel the clips leave open, nil where there are no clips.
    func share(_ x: Int, _ y: Int) -> Float? {
        mask?[x, y]
    }
}
