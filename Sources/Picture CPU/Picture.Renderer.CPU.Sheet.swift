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

    /// The steps of the layer's effects, in order, leaving out those that change nothing; nil when the
    /// layer's transform squashes the plane, so that nothing is drawn on the sheet.
    static func steps(_ layer: Picture.Layer, _ transform: Picture.Transform) throws(Picture.Renderer.Error) -> [Picture.Renderer.CPU.Step]? {
        guard let inverse = Picture.Renderer.CPU.State(transform: transform, mask: nil).inverse else { return nil }
        var steps: [Picture.Renderer.CPU.Step] = []
        for effect in layer.effects {
            steps += try Picture.Renderer.CPU.Step.steps(effect, transform, inverse)
        }
        return steps
    }

    /// The sheet with the content drawn on it and the effects applied, over the target's pixels at most.
    ///
    /// The boxes are worked out backwards: the last covers the target, and each step before it covers what
    /// the step after it reads. Each is cut to the box outside which that stage of the sheet is known to be
    /// transparent, which for the first is the box around the content.
    func drawn() throws(Picture.Renderer.Error) -> Picture.Renderer.CPU.Canvas {
        guard let steps = try Self.steps(layer, state.transform) else { return Picture.Renderer.CPU.Canvas(.empty, repeating: .transparent) }
        var support = Picture.Renderer.CPU.Canvas.bounds(of: layer.content, state.transform)
        var supports = [support]
        for step in steps {
            support = step.support(support)
            supports.append(support)
        }
        var boxes = [Picture.Renderer.CPU.Box](repeating: .empty, count: supports.count)
        var needed = target
        var stage = steps.count
        while stage >= 0 {
            let box = supports[stage].map { needed.intersection($0) } ?? needed
            guard box.area <= Picture.Renderer.CPU.limit else { throw .unsupported }
            boxes[stage] = box
            if stage > 0 { needed = steps[stage - 1].reads(box) }
            stage -= 1
        }
        var sheet = Picture.Renderer.CPU.Canvas(boxes[0], repeating: .transparent)
        try sheet.draw(layer.content, Picture.Renderer.CPU.State(transform: state.transform, mask: nil, workers: state.workers))
        for (step, box) in zip(steps, boxes.dropFirst()) {
            sheet = step.applied(to: sheet, over: box, state.workers)
        }
        return sheet
    }
}
