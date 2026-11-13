import Picture

extension Picture.Renderer.CPU {
    /// The measures of a glass model with a body, in eye space: how thick it is and where the picture behind it
    /// stands.
    struct Body {
        /// The least of the sides of the box around the mesh in its own space, each as long as view times model
        /// makes it: the body's own thickness, which no turn of the camera changes.
        let thickness: Double

        /// The depth in eye space of the plane the picture behind stands on: the refraction's distance, in units
        /// of the picture, behind the body's farthest point from the eye.
        let plane: Double
    }
}

extension Picture.Renderer.CPU.Body {
    /// The body of a scene's model under its camera, drawn through a lens into a picture whose units are `scale`
    /// raster pixels; nil without a refraction or vertices.
    init?(_ model: Picture.Scene.Model, eye: Matrix<4, 4, Double>, lens: Picture.Renderer.CPU.Lens, scale: Double) {
        guard case .glass(let glass) = model.material, let refraction = glass.refraction else { return nil }
        let vertices = model.mesh.vertices
        guard let first = vertices.first else { return nil }
        var lower = (first[0], first[1], first[2])
        var upper = lower
        var farthest = Double.infinity
        var centre = (0.0, 0.0, 0.0)
        for vertex in vertices {
            lower = (Swift.min(lower.0, vertex[0]), Swift.min(lower.1, vertex[1]), Swift.min(lower.2, vertex[2]))
            upper = (Swift.max(upper.0, vertex[0]), Swift.max(upper.1, vertex[1]), Swift.max(upper.2, vertex[2]))
            let z = eye[2, 0] * vertex[0] + eye[2, 1] * vertex[1] + eye[2, 2] * vertex[2] + eye[2, 3]
            farthest = Swift.min(farthest, z)
        }
        let count = Double(vertices.count)
        for vertex in vertices {
            centre.0 += vertex[0] / count
            centre.1 += vertex[1] / count
            centre.2 += vertex[2] / count
        }
        func stretch(_ column: Int) -> Double {
            (eye[0, column] * eye[0, column] + eye[1, column] * eye[1, column] + eye[2, column] * eye[2, column]).squareRoot()
        }
        let sides = [(upper.0 - lower.0) * stretch(0), (upper.1 - lower.1) * stretch(1), (upper.2 - lower.2) * stretch(2)]
        let positive = sides.filter { $0 > 0 && $0.isFinite }
        let middle = Vector<3, Double>([
            eye[0, 0] * centre.0 + eye[0, 1] * centre.1 + eye[0, 2] * centre.2 + eye[0, 3],
            eye[1, 0] * centre.0 + eye[1, 1] * centre.1 + eye[1, 2] * centre.2 + eye[1, 3],
            farthest,
        ])
        let units = Self.pixels(at: middle, lens)
        let distance = Swift.max(refraction.distance, 0)
        let behind = units > 0 && units.isFinite && distance.isFinite ? distance * scale / units : 0
        self.init(thickness: positive.min() ?? 1, plane: farthest - behind)
    }

    /// How many raster pixels one unit of eye space across the line of sight spans at a place: the mean of the
    /// lengths a unit step along x and along y is drawn at.
    static func pixels(at place: Vector<3, Double>, _ lens: Picture.Renderer.CPU.Lens) -> Double {
        guard let here = lens.raster(of: place),
            let across = lens.raster(of: Vector([place[0] + 1, place[1], place[2]])),
            let up = lens.raster(of: Vector([place[0], place[1] + 1, place[2]]))
        else { return 0 }
        let a = ((across.x - here.x) * (across.x - here.x) + (across.y - here.y) * (across.y - here.y)).squareRoot()
        let b = ((up.x - here.x) * (up.x - here.x) + (up.y - here.y) * (up.y - here.y)).squareRoot()
        return (a + b) / 2
    }
}
