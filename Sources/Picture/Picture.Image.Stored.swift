extension Picture.Image {
    /// How an image keeps its content: pixels with the hash of their values, made once for every copy, or the
    /// drawing's source, hashed when it was made.
    enum Stored: Sendable {
        case pixels(Held)
        case drawing(Source)
    }
}
