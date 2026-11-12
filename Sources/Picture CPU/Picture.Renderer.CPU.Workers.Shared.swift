import Picture

extension Picture.Renderer.CPU.Workers {
    /// The work of each part, shared with the threads for as long as `run` waits for them.
    struct Shared: @unchecked Sendable {
        let body: (_ part: Int) -> Void
    }
}
