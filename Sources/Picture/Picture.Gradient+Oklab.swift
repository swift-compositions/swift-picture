extension Picture.Gradient {
    /// This gradient going from stop to stop through Oklab: each stretch between two stops becomes `steps`
    /// equal stretches, and the stops put between take the two stops' colours mixed in Oklab by
    /// `Picture.Color.mixed(inOklabTo:at:)`. Each short stretch is still read in linear light, so more steps
    /// come closer to Oklab at every parameter. Two stops at one offset stay a hard edge with nothing between,
    /// and fewer than two steps, or fewer than two stops, give the gradient back as it is.
    public func oklab(steps: Int) -> Self {
        guard steps > 1, let first = stops.first else { return self }
        var result: [Stop] = [first]
        var previous = first
        var floor = first.offset
        for stop in stops.dropFirst() {
            let offset = Swift.max(stop.offset, floor)
            if offset > floor {
                for step in 1..<steps {
                    let share = Double(step) / Double(steps)
                    result.append(Stop(offset: floor + (offset - floor) * Float(share), color: previous.color.mixed(inOklabTo: stop.color, at: share)))
                }
            }
            result.append(stop)
            previous = stop
            floor = offset
        }
        return Self(result)
    }
}
