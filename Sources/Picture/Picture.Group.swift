extension Picture {
    /// A picture moved by a transform and limited to a clip. Its elements draw straight onto what is behind.
    public struct Group: Sendable, Hashable {
        public var content: Picture
        public var transform: Picture.Transform
        public var clip: Clip?

        public init(_ content: Picture, transform: Picture.Transform = .identity, clip: Clip? = nil) {
            self.content = content
            self.transform = transform
            self.clip = clip
        }
    }
}
