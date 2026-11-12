import Picture

extension Picture.Renderer.CPU.Workers {
    /// The pixels of a canvas as the threads share them: each thread writes only the pixels of its own part.
    @unsafe struct Pixels: @unchecked Sendable {
        let base: UnsafeMutablePointer<Picture.Pixel>
    }
}

extension Picture.Renderer.CPU.Workers.Pixels {
    subscript(index: Int) -> Picture.Pixel {
        get { unsafe base[index] }
        nonmutating set { unsafe base[index] = newValue }
    }
}
