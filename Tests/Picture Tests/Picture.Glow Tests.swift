import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A glow can spare what a mask covers` {}
}

extension `Picture Tests`.`A glow can spare what a mask covers` {
    typealias Tests = `Picture Tests`

    @Test
    func `Without a mask a glow is the one layer of light it always was`() {
        let picture: Picture = [Tests.shape(4, .white)]
        #expect(picture.glow(deviation: 3, strength: 0.5, sparing: .empty) == picture.glow(deviation: 3, strength: 0.5))
        #expect(
            picture.glow(deviation: 3, strength: 0.5).elements.last
                == .layer(.init(picture, effects: [.blur(.init(deviation: 3))], opacity: 0.5, operator: .lighter))
        )
    }

    @Test
    func `With a mask the light is the blurred picture less the mask, added with the strength`() {
        let picture: Picture = [Tests.shape(4, .white)]
        let mask: Picture = [Tests.shape(1, .black)]
        let light: Picture = [
            .layer(.init(picture, effects: [.blur(.init(deviation: 2))])),
            .layer(.init(mask, operator: .destinationOut)),
        ]
        #expect(
            picture.glow(deviation: 2, strength: 0.75, sparing: mask).elements
                == picture.elements + [.layer(.init(light, opacity: 0.75, operator: .lighter))]
        )
    }
}
