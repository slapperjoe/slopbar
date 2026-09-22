# DMS Plugin Development Learnings

## Critical Architecture Facts (AvengeMedia/DankMaterialShell)

### Plugin Manifest Requirements
- `type` must be a **string** ("widget", "daemon", "launcher", "desktop"). Arrays like `["widget", "desktop-widget"]` cause silent rejection by the plugin scanner.
- `permissions` array controls what the plugin can do. `settings_write` is required for saving settings.

### PluginComponent (Widget QML)
- **No `stringSetting()`, `boolSetting()`, `setString()`, `setBool()`** — these methods do NOT exist on `PluginComponent`.
- Read settings via: `pluginData["key"] || defaultValue`
- Write settings via: `pluginService.savePluginData(pluginId, key, value)`
- `pluginData` is a dict-like object populated from `SettingsData.getPluginSettingsForPlugin(pluginId)`
- `pluginService` is injected by `PluginService.loadPlugin()` with `{ "pluginService": root }`

### PluginSettings (Settings QML)
- Extends `Item`, provides `saveValue(key, value)` and `loadValue(key, defaultValue)` methods
- Does NOT have `pluginData.stringSetting()` — these methods don't exist
- Use `StringSetting` and `ToggleSetting` components from `qs.Modules.Plugins` for settings UI
- `StringSetting`: auto-handles load/save via `findSettings()` → `settings.saveValue()`
- `ToggleSetting`: same pattern, handles bool settings
- `PluginSettingsRow`, `PluginSettingsSelector`, `PluginSettingsToggle` do NOT exist in DMS — these are custom/named-wrong components

### Audio / Pipewire API
- `Pipewire.sinks` does NOT exist as a property
- Get sinks via: `Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)`
- `PwNode` properties: `name`, `description`, `audio`, `isSink`, `isStream`
- Change default sink: `Pipewire.preferredDefaultAudioSink = node`
- `Pipewire.defaultAudioSink` returns the current default `PwNode`
- `AudioService` is a DMS-side singleton wrapping Pipewire for sound playback and volume control

### Plugin Loading Flow
1. `PluginService.resyncAll()` scans `~/.config/DankMaterialShell/plugins/` for `plugin.json`
2. Manifests are parsed; if `type` is an array, manifest is marked `bad` and skipped
3. `enablePlugin()` calls `SettingsData.setPluginSetting(pluginId, "enabled", true)` then `loadPlugin()`
4. `loadPlugin()` uses `Qt.createComponent(url, Component.PreferSynchronous)`
5. If QML has compile-time errors (e.g., referencing non-existent components/properties), component creation fails with `Component.Error`
6. Failed loads trigger `pluginLoadFailed()` signal → DMS shows "Failed to enable plugin: <name>"
7. Bump `version` in `plugin.json` to force cache busting after QML fixes
8. `console.error()` in `Component.onCompleted` writes to stderr — visible in DMS terminal output

### Minimal Working Plugin
- Stripped widget to bare-bones `PluginComponent` with only `horizontalBarPill`
- No `Pipewire` import, no `QtQuick.Layouts`, no `ColumnLayout`
- Settings reduced to single `StringSetting` inside `PluginSettings`
- `pluginData["key"] || default` for reading, `pluginService.savePluginData()` for writing

### Common Pitfalls
- Shadowing `pluginData` property kills settings access
- Calling non-existent methods (`stringSetting`, `setString`) causes QML compilation failure → plugin won't load
- Using non-existent components (`PluginSettingsRow`, `PluginSettingsSelector`, `PluginSettingsToggle`) → compilation failure
- `Pipewire.sinks` doesn't exist → use `Pipewire.nodes.values.filter(...)`
- `HoverHandler` does NOT exist in DMS → use standard `MouseArea` with `hoverEnabled: true`
- `barHovered` property does NOT exist on `PluginComponent` → don't reference it
- Missing `import QtQuick.Layouts` when using `ColumnLayout`, `RowLayout`, or `Layout.fillWidth` → causes silent QML compilation failure
- `PopoutComponent` is available via `qs.Modules.Plugins` and provides `closePopout()` callback for closing the popout
- `MouseArea.onWheel` receives an `event` object with `angleDelta.y` for scroll direction

## Bar Pill Rendering & Click Handling (DMS BasePill)

### BasePill QML Structure
- `BasePill.qml` is the visual wrapper for bar widgets. It:
  1. Uses `ContentLoader` (`pillContentLoader`) to load the pill component from `horizontalBarPill` / `verticalBarPill`
  2. Wraps the `ContentLoader` in a `MouseArea` that handles **all** interaction:
     - Left-click → `pillClickAction` callback
     - Right-click → `pillRightClickAction` callback
     - Mouse wheel → cycles through sinks or scrolls
      - Hover → changes background transparency (does NOT auto-show popout)
   3. Popout is NOT shown on hover — it must be explicitly triggered via `pillClickAction` or `pillRightClickAction` calling `root.triggerPopout()`
  4. `popoutWidth` and `popoutHeight` control popout dimensions

### Pill Content Requirements
- The pill component (e.g., `horizontalBarPill`) MUST have implicit dimensions
- A bare `MouseArea` has **no implicit size** → pill renders invisible/empty
- Use `Row` with `DankIcon` and `StyledText` (has natural implicit width from text)
- **Do NOT** put a `MouseArea` inside the pill — `BasePill` already provides one
- Interaction is routed through `pillClickAction` and `pillRightClickAction` callbacks

### Popout Content & PopoutComponent Layout
- `popoutContent` takes a `Component` with `PopoutComponent`
- `PopoutComponent` extends `Column`, provides `headerText`, `detailsText`, `showCloseButton`, `closePopout`, `parentPopout`
- `closePopout` callback is injected by `PluginPopout.onLoaded` — calling it closes the popout
- `parentPopout` reference is also injected for accessing the parent `DankPopout`
- **CRITICAL**: `PopoutComponent` is a `Column` with no inherent height. Any `ListView` inside it **must have an explicit height** — `anchors.fill: parent` results in zero height because the Column has no height to fill
- The popout height is determined by `pluginPopout.contentHeight` which binds to `item.implicitHeight`. Give child components explicit dimensions for reliable rendering
- The popout is shown on hover by default; `pillRightClickAction` can be used to toggle it

## DankIcon & Material Symbols Icons
- `DankIcon` wraps `StyledText` with Material Symbols Rounded font
- **Icon names MUST be valid Material Symbols names** — `"audio"` is NOT a valid name
- Valid names: `"volume_up"`, `"volume_down"`, `"headphones"`, `"speaker"`, `"headset"`, `"cast_connected"`, etc.
- Find available icons in `MaterialSymbolsRounded[FILL,GRAD,opsz,wght].codepoints`
- `DankIcon` properties: `name` (icon text), `size` (font pixelSize), `color`, `filled` (FILL axis 0 or 1)
- `DankIcon` has `implicitWidth` and `implicitHeight` based on `size`

## PluginPopout & Popout Triggering
- `PluginPopout` wraps `DankPopout` and manages `popoutContent` loading
- `popoutTarget` on `BasePill` is set to `pluginPopout` for context/position setup
- Popout is **not** shown on hover — it must be explicitly triggered
- Call `root.triggerPopout()` from `pillRightClickAction` to show the popout on right-click
- `PopoutComponent` is the content wrapper with header, details, and `closePopout()` callback

## triggerPopout() Early-Return Bug
- `PluginComponent.triggerPopout()` checks `if (pillClickAction)` and calls it, then returns early
- This means if `pillClickAction` is defined, calling `triggerPopout()` will **never** reach the popout toggle code
- **Workaround**: call `pluginPopout.toggle()` directly from `pillRightClickAction` instead of `root.triggerPopout()`
- `pluginPopout` is a child `PluginPopout` in `PluginComponent` — accessible by `id` from the extending widget

## Popout Positioning Requirements
- `pluginPopout.toggle()` alone is insufficient — popout must be positioned first
- Call `pluginPopout.setTriggerPosition(x, y, width, section, screen, barPosition, barThickness, barSpacing, barConfig)`
- Use `SettingsData.getPopupTriggerPosition()` to compute the correct screen position based on bar edge
- Without `setTriggerPosition`, the popout appears at (0,0) — effectively invisible
- `barPosition` is derived from `axis?.edge`: top=0, bottom=1, left=2, right=3
- `qs.Services` must be imported for `SettingsData`

## pillRightClickAction Signature
- `BasePill.onRightClicked` checks `pillRightClickAction.length`
- If length is 0, calls `pillRightClickAction()` with no arguments
- If length > 0, calls `pillRightClickAction(pos.x, pos.y, pos.width, section, currentScreen)`
- The 5-arg version receives position data from `SettingsData.getPopupTriggerPosition()`
- Inside the action, `pluginPopout`, `barConfig`, `barThickness`, `barSpacing`, `section`, and `axis` are all inherited from `PluginComponent`
- `pluginPopout` is accessible by ID from the widget file

## Plugin Caching & Version
- Version bump in `plugin.json` may NOT bust the QML cache
- DMS uses `Qt.createComponent(url, Component.PreferSynchronous)` which caches components
- To force reload: restart DMS completely or clear `~/.cache/quickshell/`
- Cached QML files may persist across sessions unless explicitly cleared

## Audio Switcher — matching main branch behavior
- The main branch audio section used `AudioService` (not raw `Pipewire.nodes`)
- Pill was icon-only (no text). Icon type was dynamic: `speaker`, `headset`, or `monitor` based on `AudioService.sinkIcon()`
- Left-click opened the popout (did NOT cycle sinks) — matching `deferSectionPopout("audio")`
- Popout used a `Flow` + `Repeater` with sink cards (icon + label), not a `ListView`
- Popout filtered sinks based on `audioQuickSwitchPrimary` / `audioQuickSwitchSecondary` settings
- Popout also showed a "current device" info card at the bottom with icon, name, and subtitle
- Settings included: `audioQuickSwitchEnabled`, `popoutOpenOnClick`, `audioQuickSwitchPrimary`, `audioQuickSwitchSecondary`
- `AudioService.getAvailableSinks()` returns the sink list. `AudioService.displayName()`, `AudioService.sinkIcon()`, `AudioService.subtitle()` provide formatting helpers
- `Pipewire.preferredDefaultAudioSink = sink` is still used to change the active output
- The pill used `DankRipple` for press animation (matching main branch)

## Do NOT shadow barThickness

- `PluginComponent` already provides `barThickness: 48` and `widgetThickness: 30`
- **Never** redefine `readonly property real barThickness` in your widget — it overrides the inherited value
- Shadowing with a fallback like `root.barConfig ? root.barConfig.thickness : 40` causes a default drop from 48 → 40px
- This pushes the pill down by 8px, creating persistent vertical misalignment
- diskMonitor and audioSwitcher do NOT shadow `barThickness` — follow their pattern
- memoryMonitor and gpuMonitor DO shadow it and may have the same alignment bug

## Required Imports for Widget Plugins
- `import qs.Services` is REQUIRED for `ToastService` (in `dms/Services/ToastService.qml`) and `AudioService` (in `dms/Services/AudioService.qml`)
- Without `import qs.Services`, both are undefined → QML compilation failure → plugin won't load
- The full set of imports needed for a typical widget: `qs.Common`, `qs.Services`, `qs.Widgets`, `qs.Modules.Plugins`
- `import Quickshell.Services.Pipewire` is needed for `Pipewire.preferredDefaultAudioSink`
- `import Quickshell.Io` is needed for `File` class (file logging)

## PluginPopout Direct Access — DOES NOT work
- `pluginPopout` is defined with `id: pluginPopout` inside `PluginComponent.qml`
- IDs from the base class are **not accessible** from extending widgets (`ReferenceError: pluginPopout is not defined`)
- `root.pluginPopout` also fails — IDs are not properties
- **Must use children iteration**: loop through `root.children` and find the child that has `setTriggerPosition` method
- The `PluginPopout` child in `PluginComponent` is instantiated but its ID is scoped to the base file

## Desktop-Widget Plugin Pattern (type: "desktop")
- For a standalone desktop widget (not bar), set `"type": "desktop"` + `"capabilities": ["desktop-widget", ...]` in plugin.json. This registers the plugin in `DesktopWidgetRegistry.pluginDesktopComponents`.
- The widget QML extends `DesktopPluginComponent` (NOT `PluginComponent`). It provides `minWidth`/`minHeight` and `pluginData` for config.
- Instances are stored in `settings.json` → `desktopWidgetInstances` with shape:
  `{ id, widgetType, name, enabled, config: {...}, positions: { "<screenKey>": { x, y, width, height } } }`
  - screenKey = `SettingsData.getScreenDisplayName(screen)` (e.g. "DP-1" with displayNameMode "system").
  - Positions are LOGICAL pixels (screen at DPR 1.25 = 3072x1728 for a 3840x2160 display).
- The wrapper (`DesktopPluginWrapper.qml`) clamps size to `max(minWidth, ...)`/`max(minHeight, ...)`, so set `minHeight` small to allow tight layouts. There is NO IPC to set instance size directly — the user resizes via the corner handle (wrapper persists its own saved size).
- Drag = right-button drag; resize = bottom-right purple handle.
- Hot reload a changed plugin: `dms ipc call plugins reload <pluginId>` (PluginService logs "Plugin unloaded/loaded").
- `dms ipc call desktopWidget list` shows instances. The QML `PluginService` (what discovers plugins) is separate from the Go daemon's `plugin-scan` — the latter can be empty even when plugins work.

## Pinning a desktop widget to a screen corner (survives scale changes)
- The wrapper positions the widget via `WlrLayershell.margins` — a plain saved x/y drifts away from the corner when the screen scale/DPR changes, because the widget keeps its absolute offset.
- A COORDINATE-ONLY recompute (`widgetX = screenWidth - width - margin`) does NOT reliably track on scale change — the user reported the pin held at scale 1 but the widget didn't follow the corner when zoomed.
- The robust fix is NATIVE layer-shell corner anchoring: set `WlrLayershell.anchors` to the corner (e.g. `right: true; bottom: true`) with right/bottom margins. The compositor (wlroots) keeps the surface pinned to that corner and repositions it automatically on any output scale/geometry change.
- Implemented in `patches/desktop-widget-corner-pin.patch` (applied to the system wrapper by `patches/apply-corner-pin.sh`). Instance config keys:
  - `pinToCorner: true` (or `positionAnchor: "bottomRight"` / `"topLeft"` / `"topRight"` / `"bottomLeft"`)
  - `cornerMargin` (px, both axes) or per-axis `anchorMarginX` / `anchorMarginY`
- The plugin's own `DigitalClockSettings.qml` exposes the toggle + margin slider; the instance-scoped `pluginService.savePluginData` writes them into the instance config.
- Dragging is disabled while anchored (`!root.anchored` on the dragArea); resize still works.
- `dms-shell` package updates overwrite the system wrapper — re-run `apply-corner-pin.sh` after upgrades.
