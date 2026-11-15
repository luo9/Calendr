import Foundation

/// 全部设置，持久化到 UserDefaults。
/// 时区的唯一入口是 `calendar`：菜单栏和月历都从它取时区，不要在别处直接用 `TimeZone.current`。
final class Settings: ObservableObject {

    static let shared = Settings()
    static let defaultDateFormat = "M/d EEE HH:mm"

    private enum Key {
        static let timeZone = "time_zone"
        static let dateFormat = "date_format"
        static let firstWeekday = "first_weekday"
        static let showWeekNumbers = "show_week_numbers"
        static let highlightWeekends = "highlight_weekends"
    }

    private let defaults: UserDefaults

    /// 空串 = 跟随系统时区
    @Published var timeZoneID: String {
        didSet { defaults.set(timeZoneID, forKey: Key.timeZone) }
    }

    /// DateFormatter 的格式串，用于菜单栏文字
    @Published var dateFormat: String {
        didSet { defaults.set(dateFormat, forKey: Key.dateFormat) }
    }

    /// 0 = 跟随系统，1...7 = 周日...周六
    @Published var firstWeekday: Int {
        didSet { defaults.set(firstWeekday, forKey: Key.firstWeekday) }
    }

    @Published var showWeekNumbers: Bool {
        didSet { defaults.set(showWeekNumbers, forKey: Key.showWeekNumbers) }
    }

    @Published var highlightWeekends: Bool {
        didSet { defaults.set(highlightWeekends, forKey: Key.highlightWeekends) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        timeZoneID = defaults.string(forKey: Key.timeZone) ?? ""
        dateFormat = defaults.string(forKey: Key.dateFormat) ?? Self.defaultDateFormat
        firstWeekday = defaults.integer(forKey: Key.firstWeekday)
        showWeekNumbers = defaults.object(forKey: Key.showWeekNumbers) as? Bool ?? false
        highlightWeekends = defaults.object(forKey: Key.highlightWeekends) as? Bool ?? true
    }

    /// 带自定义时区和周起始日的日历。每次取用都重新构建，所以系统时区/区域变化会自动跟随。
    var calendar: Calendar {
        let system = Calendar.autoupdatingCurrent
        var calendar = system
        // 界面固定英文：月份/星期名用英文，但周起始日、每年第一周规则仍沿用系统区域设置
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = system.firstWeekday
        calendar.minimumDaysInFirstWeek = system.minimumDaysInFirstWeek
        if !timeZoneID.isEmpty, let timeZone = TimeZone(identifier: timeZoneID) {
            calendar.timeZone = timeZone
        }
        if (1...7).contains(firstWeekday) {
            calendar.firstWeekday = firstWeekday
        }
        return calendar
    }
}
