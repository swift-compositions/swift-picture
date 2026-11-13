import Picture
import Standard_Library_Extensions
import Testing

@Suite struct `Picture.Image.Source Canonical Tests` {
    @Test func `a source's canonical value holds every stored property but its Hasher value`() throws {
        let rectangle = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 8, ury: 8)
        let source = Picture.Image.Source([], in: rectangle, scale: 2, samples: 3)
        // A property added to the source fails this until the canonical value holds it too.
        #expect(Mirror(reflecting: source).children.map(\.label) == ["picture", "rectangle", "scale", "samples", "digest"])
        let canonical = try #require(source.canonical as? (Picture, Picture.Plane.Rectangle, Double, Cardinal))
        #expect(canonical.0 == source.picture && canonical.1 == source.rectangle && canonical.2 == 2 && canonical.3 == 3)
    }
}
