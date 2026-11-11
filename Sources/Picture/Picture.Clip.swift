public import Direction

extension Picture {
    /// A region that limits where a group draws.
    public struct Clip: Sendable, Hashable {
        public var path: Picture.Path
        public var rule: Winding.Rule

        public init(_ path: Picture.Path, rule: Winding.Rule = .nonzero) {
            self.path = path
            self.rule = rule
        }
    }
}
