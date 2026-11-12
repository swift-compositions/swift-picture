import Picture
import Synchronization

extension Picture.Renderer.CPU.Workers {
    /// The number of the next part to take.
    final class Next: Sendable {
        let value = Atomic<Int>(0)
    }
}
