import AppKit
import Combine
import SwiftUI

/// 菜单栏图标：显示按所选时区格式化的时间；左键弹出月历，右键弹出菜单。
@MainActor
final class StatusItemController: NSObject {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let settings: Settings
    private let openSettings: () -> Void

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: Settings, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        super.init()

        popover.behavior = .transient

        if let button = statusItem.button {
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // objectWillChange 在值变化之前触发，所以下一轮 runloop 再刷新
        settings.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
            .store(in: &cancellables)

        for name in [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
                .store(in: &cancellables)
        }

        startTimer()
        refresh()
    }

    private func startTimer() {
        // 对齐到整秒，之后每秒刷新一次（格式里没有秒时标题不变，不会重绘）
        let nextSecond = Date(timeIntervalSinceReferenceDate: ceil(Date.timeIntervalSinceReferenceDate))
        let timer = Timer(fire: nextSecond, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        let text = formatDate(Date(), pattern: settings.dateFormat, calendar: settings.calendar)
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

    private func showMenu() {
        popover.performClose(nil)

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Calendr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // 临时挂上菜单再点击，菜单弹出后立即摘掉，这样左键仍然走 action
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettingsAction() {
        openSettings()
    }
}
