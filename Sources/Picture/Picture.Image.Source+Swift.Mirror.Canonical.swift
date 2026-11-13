public import Standard_Library_Extensions

extension Picture.Image.Source: Swift.Mirror.Canonical {
    /// What decides a source's raster, without the `Hasher` value it keeps, which differs from process to process.
    public var canonical: Any { (picture, rectangle, scale, samples) }
}
