#if PNG
    public import Picture

    extension Picture.PNG {
        public enum Error: Swift.Error, Sendable, Hashable {
            case encoding

            case index
        }
    }
#endif
