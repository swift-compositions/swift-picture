extension Picture.Image {
    /// Why a drawing gave no raster for a reason of its own, such as pixels read from elsewhere that did not
    /// arrive: the drawing's own error, kept with its type and value.
    ///
    /// The error is `Hashable`, so a failure is a value like the renderer's error that carries it: two failures
    /// are equal exactly when their errors are of one type and equal, and they hash as their errors do.
    public struct Failure: Sendable {
        /// The drawing's own error.
        public let error: any Swift.Error

        /// Whether a value is an error of the same type, equal to this one.
        let same: @Sendable (any Swift.Error) -> Bool

        /// Hashes the error's type and value.
        let hashing: @Sendable (inout Hasher) -> Void

        /// The failure of a drawing's own error.
        public init<Value: Swift.Error & Hashable>(_ error: Value) {
            self.error = error
            self.same = { other in (other as? Value) == error }
            self.hashing = { hasher in
                hasher.combine(ObjectIdentifier(Value.self))
                hasher.combine(error)
            }
        }
    }
}

extension Picture.Image.Failure {
    /// The drawing's own error, if it is of a type.
    public func error<Value: Swift.Error>(as type: Value.Type) -> Value? {
        error as? Value
    }
}

extension Picture.Image.Failure: Hashable {
    public static func == (first: Self, second: Self) -> Bool {
        first.same(second.error)
    }

    public func hash(into hasher: inout Hasher) {
        hashing(&hasher)
    }
}

extension Picture.Image.Failure: CustomStringConvertible {
    /// The drawing's own error, as it describes itself.
    public var description: Swift.String {
        Swift.String(describing: error)
    }
}
