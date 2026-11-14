extension Picture.Glass {
    /// What the glass is where it bends what it reads: a skin with no depth, or a body that light passes through.
    public enum Surface: Sendable, Hashable {
        /// A skin: the picture behind is read `offset(for:)` aside, `bend` times the normal's x and minus its y,
        /// under a coat of the tint.
        case skin(bend: Double)

        /// A body: light bends where it goes in and again where it leaves, by Snell's law in the body's medium,
        /// and the tint is taken on along the way.
        case body(Body)
    }
}
