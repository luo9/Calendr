import SwiftUI

/// 点击菜单栏弹出的月历。每次弹出都会重新创建，所以总是从"今天"开始。
struct CalendarPopoverView: View {

    @ObservedObject var settings: Settings

    @State private var anchor = Date()
    @State private var selected: Date?

    private let cellSize = CGSize(width: 32, height: 28)
    private let weekColumnWidth: CGFloat = 24

    var body: some View {
        // 每秒刷新一次，保证跨午夜（按所选时区）时"今天"高亮和底部时钟自动更新
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let calendar = settings.calendar
            let grid = MonthGrid(month: anchor, now: context.date, calendar: calendar)

            VStack(spacing: 8) {
                header(grid)
                weekdayRow(grid)
                ForEach(grid.weeks) { week in
                    weekRow(week, calendar: calendar)
                }
                Divider()
                footer(now: context.date, calendar: calendar)
            }
        }
        .padding(12)
        .fixedSize()
    }

    private func header(_ grid: MonthGrid) -> some View {
        HStack(spacing: 6) {
            Text(grid.title)
                .font(.headline)
            Spacer()
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                .help("Previous month")
            Button { goToToday() } label: { Image(systemName: "circle.inset.filled") }
                .help("Go to today")
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                .help("Next month")
        }
        .buttonStyle(.borderless)
    }

    private func weekdayRow(_ grid: MonthGrid) -> some View {
        HStack(spacing: 0) {
            if settings.showWeekNumbers {
                Color.clear.frame(width: weekColumnWidth, height: 1)
            }
            ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize.width)
            }
        }
    }

    private func weekRow(_ week: WeekRow, calendar: Calendar) -> some View {
        HStack(spacing: 0) {
            if settings.showWeekNumbers {
                Text("\(week.weekOfYear)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: weekColumnWidth)
            }
            ForEach(week.cells) { cell in
                dayCell(cell, calendar: calendar)
            }
        }
    }

    private func dayCell(_ cell: DayCell, calendar: Calendar) -> some View {
        let isSelected = selected.map { calendar.isDate($0, inSameDayAs: cell.date) } ?? false

        return Text("\(cell.day)")
            .font(.system(size: 13, weight: cell.isToday ? .semibold : .regular).monospacedDigit())
            .foregroundStyle(textColor(cell))
            .frame(width: cellSize.width, height: cellSize.height)
            .background {
                if cell.isToday {
                    Circle().fill(Color.accentColor)
                } else if isSelected {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selected = cell.date
                if !cell.isInMonth { anchor = cell.date }
            }
    }

    private func textColor(_ cell: DayCell) -> Color {
        if cell.isToday { return .white }
        let isWeekend = cell.isWeekend && settings.highlightWeekends
        switch (cell.isInMonth, isWeekend) {
        case (true, true): return .red.opacity(0.85)
        case (true, false): return .primary
        case (false, true): return .red.opacity(0.35)
        case (false, false): return .secondary.opacity(0.5)
        }
    }

    private func footer(now: Date, calendar: Calendar) -> some View {
        let system = Calendar.autoupdatingCurrent.with(locale: calendar.locale)
        // 自定义时区与系统时区不同时，两行都显示，方便对比
        let showsSystem = system.timeZone != calendar.timeZone

        return VStack(spacing: 2) {
            timeZoneRow(now: now, calendar: calendar)
            if showsSystem {
                timeZoneRow(now: now, calendar: system)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func timeZoneRow(now: Date, calendar: Calendar) -> some View {
        let timeZone = calendar.timeZone
        let offset = TimeZoneOptions.gmtLabel(seconds: timeZone.secondsFromGMT(for: now))
        let day = formatDate(now, pattern: "EEE d", calendar: calendar)
        let time = formatDate(now, pattern: "HH:mm", calendar: calendar)

        return HStack {
            Text("\(timeZone.identifier) · \(offset)")
            Spacer()
            Text("\(day) \(time)").monospacedDigit()
        }
    }

    private func moveMonth(_ value: Int) {
        anchor = settings.calendar.date(byAdding: .month, value: value, to: anchor) ?? anchor
    }

    private func goToToday() {
        anchor = Date()
        selected = nil
    }
}
