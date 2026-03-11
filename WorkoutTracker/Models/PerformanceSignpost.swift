import os.signpost

enum PerformanceSignpost {
    struct Interval {
        fileprivate let name: StaticString
        fileprivate let id: OSSignpostID
    }

    private static let log = OSLog(subsystem: "com.cam.workouttracker", category: .pointsOfInterest)

    static func begin(_ name: StaticString) -> Interval {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return Interval(name: name, id: id)
    }

    static func end(_ interval: Interval) {
        os_signpost(.end, log: log, name: interval.name, signpostID: interval.id)
    }

    static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name)
    }
}
