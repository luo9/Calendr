import Foundation

struct DayCell: Identifiable, Equatable {
    let date: Date
    let day: Int
    let isInMonth: Bool
    let isToday: Bool
    let isWeekend: Bool

    var id: Date { date }
}

struct WeekRow: Identifiable, Equatable {
    let weekOfYear: Int
    let cells: [DayCell]

    var id: Date { cells[0].date }
}

/// 一个月的 6 行 × 7 列网格。所有日期运算都基于传入 calendar 的时区。
struct MonthGrid: Equatable {

    let title: String
    let weekdaySymbols: [String]
    let weeks: [WeekRow]

    init(month anchor: Date, now: Date, calendar: Calendar) {

        let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start ?? calendar.startOfDay(for: anchor)

        let weekday = calendar.component(.weekday, from: monthStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: monthStart) ?? monthStart

        let days: [Date] = (0..<42).map { index in
            let date = calendar.date(byAdding: .day, value: index, to: gridStart) ?? gridStart
            return calendar.startOfDay(for: date)
        }

        weeks = stride(from: 0, to: 42, by: 7).map { start in
            let cells = days[start..<start + 7].map { date in
                DayCell(
                    date: date,
                    day: calendar.component(.day, from: date),
                    isInMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                    isToday: calendar.isDate(date, inSameDayAs: now),
                    isWeekend: calendar.isDateInWeekend(date)
                )
            }
            return WeekRow(weekOfYear: calendar.component(.weekOfYear, from: days[start]), cells: cells)
        }

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[first...] + symbols[..<first])

        title = Self.formatter(template: "yMMMM", calendar: calendar).string(from: monthStart)
    }

    private static func formatter(template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

extension Calendar {
    func with(locale: Locale?) -> Calendar {
        var copy = self
        copy.locale = locale
        return copy
    }
}

/// 按自定义格式串渲染日期（菜单栏文字用）。
func formatDate(_ date: Date, pattern: String, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = calendar.locale ?? .current
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

enum TimeZoneOptions {

    struct Option: Identifiable, Equatable {
        let id: String
        let label: String
    }

    static func gmtLabel(seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        return minutes == 0 ? "GMT\(sign)\(hours)" : "GMT\(sign)\(hours):" + String(format: "%02d", minutes)
    }

    /// 按 UTC 偏移、再按名称排序
    static func all(at date: Date = Date()) -> [Option] {
        TimeZone.knownTimeZoneIdentifiers
            .compactMap { id in TimeZone(identifier: id).map { (id, $0.secondsFromGMT(for: date)) } }
            .sorted { ($0.1, $0.0) < ($1.1, $1.0) }
            .map { Option(id: $0.0, label: "(\(gmtLabel(seconds: $0.1))) \($0.0)") }
    }
}
