import Kernel_Thread
import Picture
import Synchronization

extension Picture.Renderer.CPU {
    /// The threads that draw a frame. Work is cut into parts that do not overlap, such as bands of rows or
    /// tiles, and each part is computed the same way whichever thread takes it, so the result does not
    /// depend on how many threads there are.
    struct Workers: Sendable {
        let count: Int
    }
}

extension Picture.Renderer.CPU.Workers {
    /// One thread: every part on the calling thread, in order.
    static var one: Self { Self(count: 1) }

    /// The fewest pixels a part of work is worth handing to another thread for.
    static let worth: Int = 1 << 14

    /// The rows of a band, so that a band holds about `worth` pixels.
    static func rows(across width: Int) -> Int {
        Swift.max(1, worth / Swift.max(width, 1))
    }

    /// Calls `body` once for each part in `0..<parts`, on up to `count` threads, the calling thread among
    /// them, and returns when every part is done. With one thread, one part, or a thread that cannot be
    /// started, the parts run on the calling thread.
    func run(_ parts: Int, _ body: (_ part: Int) -> Void) {
        let threads = Swift.min(count, parts)
        guard threads > 1 else {
            var part = 0
            while part < parts {
                body(part)
                part += 1
            }
            return
        }
        let next = Next()
        withoutActuallyEscaping(body) { body in
            let shared = Shared(body: body)
            let work: @Sendable () -> Void = {
                while true {
                    let part = next.value.wrappingAdd(1, ordering: .relaxed).oldValue
                    guard part < parts else { return }
                    shared.body(part)
                }
            }
            var handles: [Kernel.Thread.Handle.Reference] = []
            var started = 1
            while started < threads {
                do throws(Kernel.Thread.Error) {
                    handles.append(Kernel.Thread.Handle.Reference(try Kernel.Thread.spawn(work)))
                } catch {
                    break
                }
                started += 1
            }
            work()
            for handle in handles {
                do throws(Kernel.Thread.Error) {
                    try handle.join()
                } catch {
                    preconditionFailure("A started thread can be joined")
                }
            }
        }
    }

    /// The number of the next part to take.
    final class Next: Sendable {
        let value = Atomic<Int>(0)
    }

    /// The work of each part, shared with the threads for as long as `run` waits for them.
    struct Shared: @unchecked Sendable {
        let body: (_ part: Int) -> Void
    }
}

extension Picture.Renderer.CPU.Workers {
    /// The pixels of a canvas as the threads share them: each thread writes only the pixels of its own part.
    @unsafe struct Pixels: @unchecked Sendable {
        let base: UnsafeMutablePointer<Picture.Pixel>

        subscript(index: Int) -> Picture.Pixel {
            get { unsafe base[index] }
            nonmutating set { unsafe base[index] = newValue }
        }
    }
}
