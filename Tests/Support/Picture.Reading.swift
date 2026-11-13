import Numeric
public import ISO_14496_22

extension Picture {
    /// The words a picture shows, read from its value rather than its pixels: every shape whose contours are a
    /// glyph of one of a few fonts, at any size and place, turned or not, taken as that glyph's character, and the
    /// characters gathered into lines along their baselines. It reads what `Picture.Text` sets, so a test can ask
    /// what a frame says without drawing it.
    public struct Reading: Sendable {
        /// The letters of the fonts, by the kinds of segments of their first contour, the letters of more contours first.
        let letters: [[Int]: [Letter]]

        /// Every kind of contour some letter has.
        let kinds: Set<[Int]>
    }
}

extension Picture.Reading {
    /// The characters it knows: printable ASCII and some common typographic marks.
    public static let scalars: [Unicode.Scalar] =
        (UInt32(0x21)...0x7E).compactMap { Unicode.Scalar($0) }
        + ["…", "·", "▲", "❯", "—", "–", "’", "‘", "“", "”", "é", "×", "→", "✓", "•"]

    /// A reading of the characters given in the fonts given: each character's glyph set at size 1, once for each
    /// distinct glyph, and those a font does not map left out.
    public init(fonts: [ISO_14496_22.FontFile], scalars: [Unicode.Scalar] = Self.scalars) {
        var letters: [[Int]: [Letter]] = [:]
        for font in fonts {
            var seen: Set<UInt16> = []
            for scalar in scalars {
                guard
                    let glyph = (try? Picture.Text(String(Character(scalar)), font: font, size: 1))?.glyphs.first,
                    glyph.index != 0,
                    seen.insert(glyph.index).inserted
                else { continue }
                let contours = glyph.outline.subpaths.compactMap { Contour($0) }
                guard let first = contours.first, contours.count == glyph.outline.subpaths.count else { continue }
                letters[first.kinds, default: []].append(Letter(scalar: scalar, contours: contours, advance: glyph.advance))
            }
        }
        self.kinds = Set(letters.values.joined().flatMap { $0.contours.map(\.kinds) })
        self.letters = letters.mapValues { candidates in
            candidates.enumerated().sorted { ($0.element.contours.count, -$0.offset) > ($1.element.contours.count, -$1.offset) }.map(\.element)
        }
    }
}

extension Picture.Reading {
    /// The lines of text the picture shows, each its characters in reading order with a space where the gap
    /// between two is wider than about a sixth of their size. Shapes in groups are read through their transforms,
    /// in layers when the layer's opacity and the paint leave them visible, and in kept images through their
    /// source picture; sprites, scenes and panes show no text.
    public func lines(in picture: Picture) -> [String] {
        var placed: [Placed] = []
        walk(picture, .identity, opacity: 1, into: &placed)
        return Self.lines(of: placed)
    }

    /// Whether some line the picture shows holds the phrase as whole words.
    public func reads(_ phrase: String, in picture: Picture) -> Bool {
        lines(in: picture).contains { Self.line($0, holds: phrase) }
    }

    /// Whether a line holds a phrase as whole words: where the phrase begins or ends with a letter or a digit,
    /// the line has none just before or after it there.
    public static func line(_ line: String, holds phrase: String) -> Bool {
        let text = Array(line)
        let wanted = Array(phrase)
        guard !wanted.isEmpty, wanted.count <= text.count else { return false }
        func word(_ character: Character?) -> Bool { character.map { $0.isLetter || $0.isNumber } ?? false }
        for start in 0...(text.count - wanted.count) where Array(text[start..<(start + wanted.count)]) == wanted {
            let before = start == 0 ? nil : text[start - 1]
            let after = start + wanted.count == text.count ? nil : text[start + wanted.count]
            if !word(wanted.first) || !word(before), !word(wanted.last) || !word(after) { return true }
        }
        return false
    }
}

extension Picture.Reading {
    func walk(_ picture: Picture, _ transform: Picture.Transform, opacity: Double, into placed: inout [Placed]) {
        for element in picture.elements {
            switch element {
            case .shape(let shape):
                read(shape, transform, opacity: opacity, into: &placed)
            case .group(let group):
                walk(group.content, transform.multiplied(by: group.transform), opacity: opacity, into: &placed)
            case .layer(let layer):
                walk(layer.content, transform, opacity: opacity * Double(layer.opacity), into: &placed)
            case .sprites, .scene, .pane:
                continue
            }
        }
    }

    func read(_ shape: Picture.Shape, _ transform: Picture.Transform, opacity: Double, into placed: inout [Placed]) {
        let paints = [shape.fill?.paint, shape.stroke?.paint].compactMap { $0 }
        var alpha = 0.0
        for paint in paints {
            switch paint {
            case .solid(let color):
                alpha = Swift.max(alpha, Double(color.alpha))
            case .image(let image):
                alpha = 1
                if let source = image.source { walk(source.picture, transform, opacity: opacity, into: &placed) }
            case .linear, .radial:
                alpha = 1
            }
        }
        guard opacity * alpha > 0.01 else { return }
        let contours = shape.path.subpaths.map { Contour($0, among: kinds) }
        let across = (x: transform[0, 0], y: transform[1, 0])
        let stretch = (across.x * across.x + across.y * across.y).squareRoot()
        let angle = Double.atan2(across.y, across.x)
        var index = 0
        while index < contours.count {
            guard let (letter, size, origin) = match(contours[index...]) else {
                index += 1
                continue
            }
            let world = transform.applied(to: Vector([origin.x, origin.y]))
            placed.append(Placed(scalar: letter.scalar, x: world[0], y: world[1], angle: angle, size: size * stretch, advance: letter.advance * size * stretch))
            index += letter.contours.count
        }
    }

    func match(_ contours: ArraySlice<Contour?>) -> (Letter, Double, (x: Double, y: Double))? {
        guard let first = contours.first, let first, let candidates = letters[first.kinds] else { return nil }
        for letter in candidates where letter.contours.count <= contours.count {
            guard let (size, origin) = Self.fit(letter.contours[0], first) else { continue }
            let fits = zip(letter.contours, contours).allSatisfy { model, seen in
                guard let seen, seen.kinds == model.kinds else { return false }
                return Self.same(model, seen, size: size, origin: origin)
            }
            if fits { return (letter, size, origin) }
        }
        return nil
    }

    /// The size and origin that put a letter's contour on a seen one, from the widest span of the letter's points.
    static func fit(_ model: Contour, _ seen: Contour) -> (Double, (x: Double, y: Double))? {
        guard model.points.count == seen.points.count, model.points.count >= 4 else { return nil }
        var widest = (axis: 0, index: 0, span: 0.0)
        for index in stride(from: 0, to: model.points.count, by: 2) {
            for axis in 0..<2 {
                let span = abs(model.points[index + axis] - model.points[axis])
                if span > widest.span { widest = (axis, index, span) }
            }
        }
        guard widest.span > 0 else { return nil }
        let a = widest.axis
        let size = (seen.points[widest.index + a] - seen.points[a]) / (model.points[widest.index + a] - model.points[a])
        guard size > 0, size.isFinite else { return nil }
        let origin = (x: seen.points[0] - size * model.points[0], y: seen.points[1] - size * model.points[1])
        return same(model, seen, size: size, origin: origin) ? (size, origin) : nil
    }

    /// Whether a seen contour is a letter's at a size and origin, to within rounding.
    static func same(_ model: Contour, _ seen: Contour, size: Double, origin: (x: Double, y: Double)) -> Bool {
        guard model.points.count == seen.points.count else { return false }
        let tolerance = 1e-6 * Swift.max(size, 1) + 1e-6 * Swift.max(abs(origin.x), abs(origin.y), 1)
        for index in stride(from: 0, to: model.points.count, by: 2) {
            guard abs(seen.points[index] - (origin.x + size * model.points[index])) <= tolerance,
                abs(seen.points[index + 1] - (origin.y + size * model.points[index + 1])) <= tolerance
            else { return false }
        }
        return true
    }

    /// Characters gathered into lines by angle and baseline, each line in order along its baseline.
    static func lines(of placed: [Placed]) -> [String] {
        var lines: [[Placed]] = []
        for letter in placed {
            let offset = letter.baseline
            if let index = lines.firstIndex(where: { line in
                let other = line[0]
                return abs(other.angle - letter.angle) < 0.01 && abs(other.baseline - offset) < 0.25 * Swift.min(other.size, letter.size)
            }) {
                lines[index].append(letter)
            } else {
                lines.append([letter])
            }
        }
        return lines.map { line in
            let sorted = line.sorted { $0.along < $1.along }
            var kept: [Placed] = []
            var text = ""
            for letter in sorted {
                let at = letter.along
                if kept.reversed().prefix(while: { at - $0.along < 0.05 * letter.size }).contains(where: { $0.scalar == letter.scalar }) { continue }
                if let last = kept.last, at - (last.along + last.advance) > 0.15 * Swift.max(letter.size, last.size) { text += " " }
                text.unicodeScalars.append(letter.scalar)
                kept.append(letter)
            }
            return text
        }
    }
}
