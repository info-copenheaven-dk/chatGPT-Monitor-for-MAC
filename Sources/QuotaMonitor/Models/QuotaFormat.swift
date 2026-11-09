import Foundation

enum QuotaFormat {
    static func date(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "da_DK")
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM.yyyy 'kl.' HH:mm"
        return formatter.string(from: date)
    }
    static func number(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "da_DK")).precision(.fractionLength(0...1)))
    }
}

