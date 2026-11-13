public import Standard_Library_Extensions

extension Picture.Image.Source: Swift.Mirror.Canonical {
    /// What decides a source's raster, its drawing, without the closures and the `Hasher` value it keeps, which
    /// differ from process to process.
    public var canonical: Any { value() }
}
