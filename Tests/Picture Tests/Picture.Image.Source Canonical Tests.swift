import Picture
import Standard_Library_Extensions
import Testing

@Suite struct `Picture.Image.Source Canonical Tests` {
    @Test func `a source's canonical value is its drawing, without its closures and its Hasher value`() throws {
        let rectangle = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 8, ury: 8)
        let source = Picture.Image.Source([], in: rectangle, scale: 2, samples: 3)
        // A property added to the source fails this until the canonical value holds it too.
        #expect(Mirror(reflecting: source).children.map(\.label) == ["pictures", "draw", "value", "same", "digest"])
        let canonical = try #require(source.canonical as? Picture.Image.Part)
        #expect(canonical == Picture.Image.Part([], in: rectangle, scale: 2, samples: 3))
        // A part is written by reflection, so every stored property of it is written.
        #expect(Mirror(reflecting: canonical).children.map(\.label) == ["picture", "rectangle", "scale", "samples"])
    }
}
