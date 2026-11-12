public import Picture

extension Picture.Renderer: Witness.Key {
    public static var liveValue: Self { .cpu }
}
