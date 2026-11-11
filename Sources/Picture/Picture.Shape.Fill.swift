public import Direction

extension Picture.Shape {
    /// A paint for the inside of a path, and the rule that says what is inside.
    public struct Fill: Sendable, Hashable {
        public var paint: Picture.Paint
        public var rule: Winding.Rule

        public init(_ paint: Picture.Paint, rule: Winding.Rule = .nonzero) {
            self.paint = paint
            self.rule = rule
        }
    }
}
