import Picture

extension Picture.Renderer.CPU.Mask {
    /// One row of a mask as `Reader.row(_:)` gives it.
    @unsafe struct Row {
        let left: Int
        let right: Int
        let base: UnsafePointer<Float>?
        let present: Bool
    }
}

extension Picture.Renderer.CPU.Mask.Row {
    /// The share the mask leaves open at a column of the row, as `State.share(_:_:)` gives it: nil without a
    /// mask, 0 outside its box.
    @inline(__always)
    func share(_ x: Int) -> Float? {
        guard unsafe present else { return nil }
        guard unsafe x >= left, unsafe x < right, let base = unsafe base else { return 0 }
        return unsafe base[x - left]
    }
}
