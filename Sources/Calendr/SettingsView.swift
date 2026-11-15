import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {

    @ObservedObject var settings: Settings

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    private let timeZoneOptions = TimeZoneOptions.all()

    private static let presets = [
        "M/d EEE HH:mm",
        "HH:mm",
        "HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "EEE d MMM HH:mm"
    ]

    var body: some View {
        Form {
            Section("Time & Date") {
                Picker("Time zone", selection: $settings.timeZoneID) {
                    Text("System default").tag("")
                    Divider()
                    ForEach(timeZoneOptions) { option in
                        Text(option.label).tag(option.id)
                    }
                }

                LabeledContent("Menu bar format") {
                    HStack {
                        TextField("", text: $settings.dateFormat)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                        Menu("Presets") {
                            ForEach(Self.presets, id: \.self) { preset in
                                Button(preset) { settings.dateFormat = preset }
                            }
                        }
                        .fixedSize()
                    }
                }

                LabeledContent("Preview") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(formatDate(context.date, pattern: settings.dateFormat, calendar: settings.calendar))
                            .monospacedDigit()
                    }
                }

                Text("Format: yyyy year, MM month, dd day, EEE weekday, HH hour, mm minute, ss second. Wrap literal text in single quotes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Calendar") {
                Picker("First day of week", selection: $settings.firstWeekday) {
                    Text("System default").tag(0)
                    ForEach(1...7, id: \.self) { weekday in
                        Text(settings.calendar.weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                Toggle("Show week numbers", isOn: $settings.showWeekNumbers)
                Toggle("Highlight weekends", isOn: $settings.highlightWeekends)
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: setLaunchAtLogin
                ))
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "Couldn't change launch at login: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class SettingsWindowController {

    private var window: NSWindow?

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: .shared))
            let window = NSWindow(contentViewController: controller)
            window.title = "Calendr Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
