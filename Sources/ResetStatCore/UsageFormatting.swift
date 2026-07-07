import Foundation

public enum UsageFormatting {
    public enum ExpiryUrgency: Equatable, Sendable {
        case expired
        case soon
        case warning
        case healthy
        case unknown
    }

    public static func planTitle(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "Unknown plan" }
        return rawValue
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    public static func resetText(timestamp: Int64?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let timestamp else { return "Reset time unavailable" }
        return resetText(date: Date(timeIntervalSince1970: TimeInterval(timestamp)), now: now, calendar: calendar)
    }

    public static func resetText(date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDateInToday(date) ? .none : .medium
        return formatter.string(from: date)
    }

    public static func timeRemainingText(timestamp: Int64?, now: Date = Date()) -> String {
        guard let timestamp else { return "Unknown" }
        return timeRemainingText(date: Date(timeIntervalSince1970: TimeInterval(timestamp)), now: now)
    }

    public static func timeRemainingText(date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Unknown" }
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "now" }

        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(max(minutes, 1))m"
    }

    public static func compactCountdownText(date: Date?, now: Date = Date()) -> String {
        guard let date else { return "?" }
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "now" }

        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)d\(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }

    public static func percentRemaining(usedPercent: Int) -> Int {
        max(0, min(100, 100 - usedPercent))
    }

    public static func compactNumber(_ value: Int64?) -> String {
        guard let value else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    public static func usd(cents: Int?) -> String {
        guard let cents else { return "--" }
        let dollars = cents / 100
        let remainder = abs(cents % 100)
        if remainder == 0 {
            return "$\(dollars)"
        }
        return String(format: "$%d.%02d", dollars, remainder)
    }

    public static func usd(micros: Int64?) -> String {
        guard let micros else { return "--" }
        let value = Double(micros) / 1_000_000
        return String(format: "$%.2f", value)
    }

    public static func expiryUrgency(expiresAt: Date?, now: Date = Date()) -> ExpiryUrgency {
        guard let expiresAt else { return .unknown }
        let days = expiresAt.timeIntervalSince(now) / 86_400
        if days < 0 {
            return .expired
        }
        if days < 7 {
            return .soon
        }
        if days <= 15 {
            return .warning
        }
        return .healthy
    }

    public static func relativeDayText(date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "date unknown" }

        let startOfNow = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfNow, to: startOfDate).day ?? 0

        if days < 0 {
            return days == -1 ? "yesterday" : "\(-days)d ago"
        }
        if days == 0 {
            return date < now ? "today" : "later today"
        }
        if days == 1 {
            return "tomorrow"
        }
        return "in \(days)d"
    }
}
