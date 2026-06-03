import Foundation

extension Date {
    var glbDayTitle: String {
        formatted(.dateTime.year().month(.wide).day().weekday(.wide))
    }

    var glbShortDayTitle: String {
        formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    var glbTimeTitle: String {
        formatted(date: .omitted, time: .shortened)
    }
}

extension Calendar {
    func startOfCurrentDay() -> Date {
        startOfDay(for: .now)
    }

    func contains(_ date: Date, in interval: DateInterval?) -> Bool {
        guard let interval else { return false }
        return interval.contains(date)
    }
}
