public import Vector

extension Picture.Glass.Pane {
    /// What light does at one point of a pane, seen straight on: the top's normal there, where the picture is read
    /// at the glass's own index and at any other, how far that light travels inside, the direction it leaves in,
    /// and what the top mirrors.
    public struct Passage: Sendable {
        /// The top's unit normal in eye space.
        public var normal: Vector<3, Double>

        /// How high the top stands here, in picture units.
        public var height: Double

        /// How far below the bottom the picture stands, in picture units; 0 for a skin.
        public var distance: Double

        /// Where the picture is read at the glass's own index, from the point, in picture units: x right, y down.
        public var offset: Vector<2, Double>

        /// How far that light travels inside the pane, in picture units.
        public var length: Double

        /// The unit direction, in eye space, in which that light leaves the bottom toward the picture.
        public var leaving: Vector<3, Double>

        /// The line of sight mirrored by the top, and the share of light the top mirrors: Fresnel's, where the
        /// glass has surroundings to mirror, and 0 where it has none.
        public var mirrored: Vector<3, Double>
        public var share: Double

        /// Whether the glass has a body; a skin reads at `offset` under every index.
        public var body: Bool
    }
}

extension Picture.Glass.Pane.Passage {
    /// The passage through a pane where its region samples so. The eye looks straight down, along minus z.
    /// With a body, light is bent into the top by Snell's law (`Refraction.Interface.refracted(_:at:)`), runs
    /// down to the flat bottom from the top's height, is bent out there, and runs on to the picture, which stands
    /// the refraction's `distance` below the bottom; `offset(for:)` is how far aside all that carries light of
    /// an index, and `offset` is that at the glass's own. A level top bends nothing, so where the top is level
    /// every offset is zero. Without a body every index reads at the glass's `offset(for:)` of the normal, and
    /// the length is 0.
    public init(through pane: Picture.Glass.Pane, for sample: Picture.Plane.Region.Sample) {
        let normal = pane.normal(for: sample)
        let sight = Vector<3, Double>([0, 0, -1])
        let mirrored = Refraction::Refraction.reflected(sight, at: normal)
        guard let refraction = pane.glass.refraction else {
            let offset = pane.glass.offset(for: normal)
            self.init(
                normal: normal,
                height: 0,
                distance: 0,
                offset: Vector([offset[0], offset[1]]),
                length: 0,
                leaving: sight,
                mirrored: mirrored,
                share: 0,
                body: false
            )
            return
        }
        let share =
            refraction.surroundings == nil
            ? 0 : Refraction::Refraction.Interface(from: .vacuum, into: refraction.index).reflectance(cosine: Swift.max(normal[2], 0))
        let height = pane.height(at: -sample.distance)
        let distance = Swift.max(refraction.distance, 0)
        var passage = Self(
            normal: normal,
            height: height,
            distance: distance,
            offset: .zero,
            length: height,
            leaving: sight,
            mirrored: mirrored,
            share: share,
            body: true
        )
        if -sample.distance >= pane.rim, pane.thickness > 0 {
            self = passage
            return
        }
        let path = passage.path(for: refraction.index)
        passage.offset = path.offset
        passage.length = path.length
        passage.leaving = path.leaving
        self = passage
    }

    /// Where light of an index reads the picture, from the point, in picture units: x right, y down.
    public func offset(for index: Refraction::Refraction.Index<Double>) -> Vector<2, Double> {
        body ? path(for: index).offset : offset
    }

    /// The way light of an index takes: bent into the top, down to the bottom, bent out, on to the picture.
    func path(for index: Refraction::Refraction.Index<Double>) -> (offset: Vector<2, Double>, length: Double, leaving: Vector<3, Double>) {
        let sight = Vector<3, Double>([0, 0, -1])
        guard normal[2] < 1 else { return (.zero, height, sight) }
        let up = Vector<3, Double>([0, 0, 1])
        let n = Swift.max(index, .vacuum)
        let inside = Refraction::Refraction.Interface(from: .vacuum, into: n).refracted(sight, at: normal).transmission ?? sight
        let run = height / Swift.max(-inside[2], 1e-6)
        let out = Refraction::Refraction.Interface(from: n, into: .vacuum).refracted(inside, at: up).value
        let beyond = distance / Swift.max(-out[2], 1e-6)
        let across = inside[0] * run + out[0] * beyond
        let along = inside[1] * run + out[1] * beyond
        return (Vector([across, -along]), run, out)
    }
}
