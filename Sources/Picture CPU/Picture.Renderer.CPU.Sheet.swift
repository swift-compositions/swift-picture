import Picture

extension Picture.Renderer.CPU {
    /// A layer's own transparent sheet: the box it must cover, worked out backwards from the pixels its
    /// composite reads, and the content drawn on it.
    struct Sheet {
        let layer: Picture.Layer
        let state: State
        let target: Box
    }
}

extension Picture.Renderer.CPU.Sheet {
    init(_ layer: Picture.Layer, _ state: Picture.Renderer.CPU.State, _ target: Picture.Renderer.CPU.Box) {
        self.init(layer: layer, state: state, target: target)
    }

    /// Whether the layer's operator leaves the backdrop as it is where the sheet is transparent, so that
    /// only the sheet's own box needs visiting.
    static func keeps(_ layer: Picture.Layer) -> Bool {
        guard layer.opacity.isFinite else { return false }
        switch layer.operator {
        case .sourceOver, .destination, .destinationOver, .destinationOut, .sourceAtop, .xor, .lighter: return true
        case .clear, .copy, .sourceIn, .destinationIn, .sourceOut, .destinationAtop: return false
        }
    }

    /// The sheet with the content drawn on it, over the target's pixels at most.
    func drawn() throws(Picture.Renderer.Error) -> Picture.Renderer.CPU.Canvas {
        guard layer.effects.isEmpty else { throw .unsupported }
        let box = target.intersection(Picture.Renderer.CPU.Canvas.bounds(of: layer.content, state.transform) ?? target)
        guard box.area <= Picture.Renderer.CPU.limit else { throw .unsupported }
        var sheet = Picture.Renderer.CPU.Canvas(box, repeating: .transparent)
        try sheet.draw(layer.content, Picture.Renderer.CPU.State(transform: state.transform, mask: nil))
        return sheet
    }
}
