extension Picture.Text.Figures {
    /// The share of a figure cell each class of character is set in, beside the digits, which take a whole
    /// cell; nil leaves a class on its own advances. The classes are Unicode's general categories: punctuation
    /// (P), such as the point, the comma and the colon; symbols (S), such as the plus sign and the percent sign;
    /// and space separators (Zs).
    public struct Cells: Sendable, Hashable {
        public var punctuation: Double?
        public var symbols: Double?
        public var spaces: Double?

        public init(punctuation: Double? = nil, symbols: Double? = nil, spaces: Double? = nil) {
            self.punctuation = punctuation
            self.symbols = symbols
            self.spaces = spaces
        }
    }
}

extension Picture.Text.Figures.Cells {
    /// The share of a figure cell a character is set in: 1 for a digit U+0030 to U+0039, its class's share for
    /// punctuation, a symbol or a space, and nil for anything else.
    public func share(of scalar: Unicode.Scalar) -> Double? {
        if ("0"..."9").contains(scalar) { return 1 }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
            .finalPunctuation, .otherPunctuation:
            return punctuation
        case .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            return symbols
        case .spaceSeparator:
            return spaces
        default:
            return nil
        }
    }
}
