import AppKit
import Combine
import SwiftUI

/// 菜单栏图标：显示按所选时区格式化的时间；左键弹出月历，右键弹出菜单。
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let formatter = DateFormatter()
    private let settings: Settings
    private let openSettings: () -> Void

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Calendr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }()

    init(settings: Settings, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        super.init()

        popover.behavior = .transient
        popover.delegate = self

        if let button = statusItem.button {
            button.font = .monospacedDigitSystemFont(ofSize: 13.5, weight: .regular)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // @Published 在 willSet 触发，receive(on: DispatchQueue.main) 确保在值更新后再重载
        Publishers.Merge3(
            settings.$timeZoneID.dropFirst().map { _ in () },
            settings.$dateFormat.dropFirst().map { _ in () },
            settings.$firstWeekday.dropFirst().map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.reload() }
        .store(in: &cancellables)

        for name in [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.reload() }
                .store(in: &cancellables)
        }

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        reload()
    }

    deinit {
        timer?.invalidate()
    }

    private func reload() {
        let calendar = settings.calendar
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = settings.dateFormat

        scheduleTimer()
        refresh()
    }

    private func scheduleTimer() {
        timer?.invalidate()

        let needsSeconds = formatNeedsSecondPrecision(settings.dateFormat)
        let interval: TimeInterval = needsSeconds ? 1 : 60
        let fireDate = nextTickDate(after: Date(), interval: interval)

        let timer = Timer(fire: fireDate, interval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = needsSeconds ? 0.05 : 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        let text = formatter.string(from: Date())
        let title = text.isEmpty ? "📅" : text
        if statusItem.button?.title != title {
            statusItem.button?.title = title
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        let controller = NSHostingController(rootView: CalendarPopoverView(settings: settings))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        controller.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }

    private func showMenu() {
        popover.performClose(nil)

        // 临时挂上菜单再点击，菜单弹出后立即摘掉，这样左键仍然走 action
        statusItem.menu = contextMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettingsAction() {
        openSettings()
    }
}
