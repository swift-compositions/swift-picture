public import Matrix
public import Mesh
public import Point

extension Picture.Scene {
    /// A mesh, where it stands in the world, and what it is made of.
    public struct Model: Sendable, Hashable {
        public var mesh: Mesh<Point::Point<3, Double>>
        public var transform: Matrix<4, 4, Double>
        public var material: Material

        public init(_ mesh: Mesh<Point::Point<3, Double>>, transform: Matrix<4, 4, Double> = .identity, material: Material) {
            self.mesh = mesh
            self.transform = transform
            self.material = material
        }
    }
}
