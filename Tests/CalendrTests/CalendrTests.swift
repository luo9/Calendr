import Foundation
import Testing
@testable import Calendr

private func makeCalendar(timeZone: String, firstWeekday: Int = 1) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(identifier: timeZone)!
    calendar.firstWeekday = firstWeekday
    return calendar
}

// 2026-11-14 20:00:00 UTC：东京已经是 11 月 15 日，UTC 和洛杉矶仍是 14 日
private let instant = Date(timeIntervalSince1970: 1_794_686_400)

@Suite struct MonthGridTests {

    @Test func sundayStartGridBeginsOnNovemberFirst() {
        // 2026-11-01 是周日
        let grid = MonthGrid(month: instant, now: instant, calendar: makeCalendar(timeZone: "UTC"))
        let first = grid.weeks[0].cells[0]
        #expect(first.day == 1)
        #expect(first.isInMonth)
        #expect(grid.weeks.count == 6)
        #expect(grid.weeks.allSatisfy { $0.cells.count == 7 })
    }

    @Test func mondayStartGridBeginsOnOctober26() {
        let grid = MonthGrid(month: instant, now: instant, calendar: makeCalendar(timeZone: "UTC", firstWeekday: 2))
        let first = grid.weeks[0].cells[0]
        #expect(first.day == 26)
        #expect(!first.isInMonth)
        #expect(grid.weekdaySymbols.first == "M")
    }

    @Test func todayFollowsTimeZone() {
        func today(in timeZone: String) -> Int? {
            let grid = MonthGrid(month: instant, now: instant, calendar: makeCalendar(timeZone: timeZone))
            return grid.weeks.flatMap(\.cells).first(where: \.isToday)?.day
        }
        #expect(today(in: "UTC") == 14)
        #expect(today(in: "Asia/Tokyo") == 15)
        #expect(today(in: "America/Los_Angeles") == 14)
    }

    @Test func titleUsesCalendarLocale() {
        let grid = MonthGrid(month: instant, now: instant, calendar: makeCalendar(timeZone: "UTC"))
        #expect(grid.title.contains("2026"))
    }
}

@Suite struct FormattingTests {

    @Test func formatRespectsTimeZone() {
        #expect(formatDate(instant, pattern: "yyyy-MM-dd HH:mm", calendar: makeCalendar(timeZone: "UTC")) == "2026-11-14 20:00")
        #expect(formatDate(instant, pattern: "yyyy-MM-dd HH:mm", calendar: makeCalendar(timeZone: "Asia/Tokyo")) == "2026-11-15 05:00")
    }

    @Test func gmtLabels() {
        #expect(TimeZoneOptions.gmtLabel(seconds: 8 * 3600) == "GMT+8")
        #expect(TimeZoneOptions.gmtLabel(seconds: -(9 * 3600 + 1800)) == "GMT-9:30")
        #expect(TimeZoneOptions.gmtLabel(seconds: 0) == "GMT+0")
    }
}

@Suite struct SettingsTests {

    private func makeDefaults() -> UserDefaults {
        let name = "CalendrTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func customTimeZoneAndFirstWeekdayApplyToCalendar() {
        let settings = Settings(defaults: makeDefaults())
        settings.timeZoneID = "Asia/Tokyo"
        settings.firstWeekday = 2
        #expect(settings.calendar.timeZone.identifier == "Asia/Tokyo")
        #expect(settings.calendar.firstWeekday == 2)
    }

    @Test func emptyOrInvalidTimeZoneFollowsSystem() {
        let settings = Settings(defaults: makeDefaults())
        let system = Calendar.autoupdatingCurrent.timeZone
        #expect(settings.calendar.timeZone == system)
        settings.timeZoneID = "Not/AZone"
        #expect(settings.calendar.timeZone == system)
    }

    @Test func valuesPersist() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        settings.timeZoneID = "Europe/Paris"
        settings.dateFormat = "HH:mm"
        settings.showWeekNumbers = true

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.timeZoneID == "Europe/Paris")
        #expect(reloaded.dateFormat == "HH:mm")
        #expect(reloaded.showWeekNumbers)
    }
}
