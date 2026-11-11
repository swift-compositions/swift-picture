extension Picture.Text {
    /// Where a line stands in the measure.
    public enum Alignment: Sendable, Hashable, CaseIterable {
        case left
        case center
        case right
    }
}

extension Picture.Text.Alignment {
    /// How far from the left of a measure a line of a width starts.
    public func indent(of width: Double, in measure: Double) -> Double {
        switch self {
        case .left: 0
        case .center: (measure - width) / 2
        case .right: measure - width
        }
    }
}
