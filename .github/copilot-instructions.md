# CPU Core Visualizer

## Build, test, and lint commands

This repository does not define automated build, lint, or test commands.

The documented validation flow is manual plugin installation into DankMaterialShell:

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r /home/mark/code/slopbar-cpu-core-visualizer ~/.config/DankMaterialShell/plugins/CpuCoreVisualizer
```

Then open **DMS Settings -> Plugins**, click **Scan for Plugins**, enable **CPU Core Visualizer**, and add `cpuCoreVisualizer` to the DankBar widget list.

There is no single-test command because there is no automated test suite in this repo.

## High-level architecture

- `plugin.json` is the plugin manifest. It wires the runtime widget to `./CpuCoreVisualizerWidget.qml` and the settings UI to `./CpuCoreVisualizerSettings.qml`.
- `CpuCoreVisualizerWidget.qml` contains the runtime behavior in a single `PluginComponent`. It:
  - reads persisted settings from `pluginData`
  - subscribes to CPU stats through `DgopService.addRef(["cpu"])`
  - refreshes stats on a polling timer with `DgopService.updateAllStats()`
  - keeps a smoothed `animatedCoreUsage` array derived from raw per-core usage
  - renders either `horizontalBarPill` or `verticalBarPill` layouts for the bar
  - shows richer per-core detail in a hover popout instead of in the compact bar itself
- `CpuCoreVisualizerSettings.qml` is only the settings surface. Its setting keys, defaults, and bounds must stay aligned with the keys read in `CpuCoreVisualizerWidget.qml`.

## Key conventions

- Keep the plugin identifier aligned everywhere: `plugin.json.id`, `CpuCoreVisualizerSettings.qml` `pluginId`, and the widget-list entry in the README are all `cpuCoreVisualizer`. The layer namespace is a separate kebab-case string: `cpu-core-visualizer`.
- New settings are a cross-file change. Add the UI control in `CpuCoreVisualizerSettings.qml`, then add or update the corresponding `numberSetting`, `stringSetting`, or `boolSetting` usage in `CpuCoreVisualizerWidget.qml`.
- Runtime numeric settings are clamped in the widget file, not trusted directly from stored values. Preserve that pattern when adding new options.
- CPU data should continue to flow through `DgopService`; pair `addRef(["cpu"])` on startup with `removeRef(["cpu"])` on destruction.
- Probe timing and visual smoothing are separate concerns: `probeInterval` controls how often fresh stats are requested, while `smoothingPercent` and `animationTimer` control how quickly the bars converge toward those samples.
- The compact widget stays bars-only. Textual detail belongs in the tooltip/popout (`tooltipText`, `shortSummaryText`, and `popoutContent`) rather than inside the bar strip.
- The README documents an intentional current limitation: top/bottom bars are the best-supported layout, while left/right bars currently fall back to horizontal-strip behavior. Preserve that expectation unless you are explicitly improving that path.
