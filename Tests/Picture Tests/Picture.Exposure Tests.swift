import Picture
import Testing

extension `Picture Tests` {
    @Suite
    struct `A mean of pictures and an exposure are compositions` {}
}

extension `Picture Tests`.`A mean of pictures and an exposure are compositions` {
    typealias Tests = `Picture Tests`

    @Test
    func `No pictures give the empty picture and one picture gives itself`() {
        let picture: Picture = [Tests.shape(4, .white)]
        #expect(Picture.mean(of: []) == .empty)
        #expect(Picture.mean(of: [picture]) == picture)
    }

    @Test
    func `Several pictures are one layer of a layer each, with one part in their number and lighter`() {
        let pictures: [Picture] = [[Tests.shape(4, .white)], [Tests.shape(2, .black)], [], [Tests.shape(1, .white)]]
        let mean = Picture.mean(of: pictures)
        #expect(
            mean.elements == [
                .layer(.init(Picture(pictures.map { .layer(.init($0, opacity: 0.25, operator: .lighter)) })))
            ]
        )
    }

    @Test
    func `The sheets of a mean add up to the mean of their pixels`() {
        let sheets = [Tests.pixel(0.5, 0.25, 0, 0.5), Tests.pixel(0, 0.5, 1, 1), Tests.pixel(0, 0, 0, 0), Tests.pixel(0.25, 0.25, 0.25, 0.25)]
        let share = Picture.Layer([], opacity: 0.25, operator: .lighter)
        let sum = sheets.reduce(Picture.Pixel.transparent) { share.composited($1, over: $0) }
        #expect(Tests.close(sum, Tests.pixel(0.1875, 0.25, 0.3125, 0.4375)))
        let opaque = (0..<7).reduce(Picture.Pixel.transparent) { sum, _ in
            Picture.Layer([], opacity: 1 / 7, operator: .lighter).composited(Tests.pixel(1, 0.5, 0.25, 1), over: sum)
        }
        #expect(Tests.close(opaque, Tests.pixel(1, 0.5, 0.25, 1)))
        #expect(opaque.alpha <= 1)
    }

    @Test
    func `An exposure asks for the picture at the midpoints of equal parts and is their mean`() {
        var asked: [Double] = []
        let exposure = Picture.exposure(samples: 4) { fraction in
            asked.append(fraction)
            return [Tests.shape(1 + fraction, .white)]
        }
        #expect(asked == [0.125, 0.375, 0.625, 0.875])
        #expect(exposure == Picture.mean(of: asked.map { [Tests.shape(1 + $0, .white)] }))
    }

    @Test
    func `No samples give the empty picture and one gives the picture at one half`() {
        #expect(Picture.exposure(samples: 0) { _ in [Tests.shape(1, .white)] } == .empty)
        #expect(Picture.exposure(samples: 1) { fraction in [Tests.shape(fraction, .white)] } == [Tests.shape(0.5, .white)])
    }

    @Test
    func `An exposure stops at the first sample that fails, with its error`() {
        struct Failure: Swift.Error, Equatable {}
        var asked = 0
        #expect(throws: Failure()) {
            try Picture.exposure(samples: 5) { (_: Double) throws(Failure) -> Picture in
                asked += 1
                if asked == 2 { throw Failure() }
                return .empty
            }
        }
        #expect(asked == 2)
    }
}
