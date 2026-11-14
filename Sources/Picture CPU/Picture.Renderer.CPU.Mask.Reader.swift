import Picture

extension Picture.Renderer.CPU.Mask {
    /// A mask, or none, read in place without copying its values, a row at a time.
    @unsafe struct Reader {
        let box: Picture.Renderer.CPU.Box
        let values: UnsafeBufferPointer<Float>
        let present: Bool
    }

    /// One row of a mask as `Reader.row(_:)` gives it.
    @unsafe struct Row {
        let left: Int
        let right: Int
        let base: UnsafePointer<Float>?
        let present: Bool
    }

    /// Calls `body` with a reader of a mask, or of no mask.
    static func reading<Result>(_ mask: Self?, _ body: (Reader) -> Result) -> Result {
        guard let mask else {
            return unsafe body(Reader(box: .empty, values: UnsafeBufferPointer(start: nil, count: 0), present: false))
        }
        return mask.values.withUnsafeBufferPointer { values in
            unsafe body(Reader(box: mask.box, values: values, present: true))
        }
    }
}

extension Picture.Renderer.CPU.Mask.Reader {
    /// The row of the mask at a row of raster space.
    @inline(__always)
    func row(_ y: Int) -> Picture.Renderer.CPU.Mask.Row {
        guard unsafe present, unsafe y >= box.top, unsafe y < box.bottom, unsafe box.width > 0, let base = unsafe values.baseAddress else {
            return unsafe Picture.Renderer.CPU.Mask.Row(left: 0, right: 0, base: nil, present: unsafe present)
        }
        return unsafe Picture.Renderer.CPU.Mask.Row(
            left: box.left,
            right: box.right,
            base: base + (y - box.top) * box.width,
            present: true
        )
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
