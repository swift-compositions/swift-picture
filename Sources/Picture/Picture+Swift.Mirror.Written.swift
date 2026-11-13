public import Standard_Library_Extensions

// A picture's parts met in their thousands write themselves for `Swift.Mirror.bytes(of:)`, where reflection costs
// about a microsecond a part. Every stored property is written, in order; the tests in `Picture Tests` list each
// type's stored properties by `Mirror` and fail when one is added, and each `switch` is exhaustive.

extension Picture: Swift.Mirror.Written {
    public func write(into writer: Swift.Mirror.Writer) -> Bool {
        guard !writer.again(elements) else { return true }
        writer.number(elements.count)
        for element in elements {
            guard element.write(into: writer) else { return false }
        }
        return true
    }
}

extension Picture.Element: Swift.Mirror.Written {
    public func write(into writer: Swift.Mirror.Writer) -> Bool {
        switch self {
        case .shape(let shape):
            writer.number(0)
            return shape.write(into: writer)
        case .sprites(let sprites):
            writer.number(1)
            return writer.write(sprites)
        case .scene(let scene):
            writer.number(2)
            return writer.write(scene)
        case .group(let group):
            writer.number(3)
            return writer.write(group)
        case .layer(let layer):
            writer.number(4)
            return writer.write(layer)
        case .pane(let pane):
            writer.number(5)
            return writer.write(pane)
        }
    }
}

extension Picture.Shape: Swift.Mirror.Written {
    public func write(into writer: Swift.Mirror.Writer) -> Bool {
        guard Self.write(path, into: writer) else { return false }
        if let fill {
            writer.number(1)
            guard fill.paint.write(into: writer), writer.write(fill.rule) else { return false }
        } else {
            writer.number(0)
        }
        if let stroke {
            writer.number(1)
            return stroke.paint.write(into: writer) && writer.write(stroke.pen)
        }
        writer.number(0)
        return true
    }

    /// A path: its subpaths, each its start, its segments and whether it is closed, a line segment by its ends.
    static func write(_ path: Picture.Plane.Path, into writer: Swift.Mirror.Writer) -> Bool {
        guard !writer.again(path.subpaths) else { return true }
        writer.number(path.subpaths.count)
        for subpath in path.subpaths {
            guard writer.write(subpath.startPoint) else { return false }
            writer.number(subpath.isClosed ? 1 : 0)
            guard !writer.again(subpath.segments) else { continue }
            writer.number(subpath.segments.count)
            for segment in subpath.segments {
                switch segment {
                case .line(let line):
                    writer.number(0)
                    guard writer.write(line.start), writer.write(line.end) else { return false }
                case .bezier(let bezier):
                    writer.number(1)
                    guard writer.write(bezier) else { return false }
                case .arc(let arc):
                    writer.number(2)
                    guard writer.write(arc) else { return false }
                case .ellipticalArc(let arc):
                    writer.number(3)
                    guard writer.write(arc) else { return false }
                }
            }
        }
        return true
    }
}

extension Picture.Paint: Swift.Mirror.Written {
    public func write(into writer: Swift.Mirror.Writer) -> Bool {
        switch self {
        case .solid(let color):
            writer.number(0)
            return writer.write(color)
        case .linear(let linear):
            writer.number(1)
            return writer.write(linear)
        case .radial(let radial):
            writer.number(2)
            return writer.write(radial)
        case .image(let image):
            writer.number(3)
            return image.write(into: writer)
        }
    }
}

extension Picture.Image: Swift.Mirror.Written {
    public func write(into writer: Swift.Mirror.Writer) -> Bool {
        writer.number(Int(clamping: raster.width))
        writer.number(Int(clamping: raster.height))
        guard writer.write(raster.pixels), writer.write(placement), writer.write(sampling) else { return false }
        switch edge {
        case .extend: writer.number(0)
        case .wrap: writer.number(1)
        case .mirror: writer.number(2)
        case .constant(let pixel):
            writer.number(3)
            guard writer.write(pixel) else { return false }
        }
        guard let source else {
            writer.number(0)
            return true
        }
        writer.number(1)
        return writer.write(source)
    }
}
