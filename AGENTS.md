# Agent instructions

极简菜单栏日历（Swift Package，无第三方依赖），自用。

- 构建/测试：`swift build`、`swift test`；打包 `scripts/build-app.sh`。
- 时区的唯一入口是 `Settings.calendar`，菜单栏和月历都从它取时区；不要在别处直接用 `TimeZone.current` / `Calendar.current`。
- 日期运算放在 `MonthGrid.swift` 这类纯函数里并写测试；UI 文件保持薄。
- 新增设置：在 `Settings` 加 `@Published` 属性并持久化，再在 `SettingsView` 加控件。

## Git

- 用户审阅全部改动前，不要 push，也不要回复评审线程。
