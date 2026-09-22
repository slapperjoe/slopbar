# SlopBar Monitoring Plugins

Split monitoring plugins for [DankBar](https://github.com/DankMachines/DankMaterialShell) and niri desktop widgets. Each plugin can run both as a compact DankBar widget and as a standalone desktop widget hosted by [DankMaterialShell](https://github.com/DankMachines/DankMaterialShell) on niri.

## Plugins

| Plugin | ID | Description |
|--------|----|-------------|
| [CPU Core Visualizer](cpuCoreVisualizer/) | `cpuCoreVisualizer` | Per-core CPU usage bars |
| [GPU Monitor](gpuMonitor/) | `gpuMonitor` | NVIDIA/AMD GPU telemetry with process popout |
| [Memory Monitor](memoryMonitor/) | `memoryMonitor` | Memory usage bar and process listing |
| [Disk Monitor](diskMonitor/) | `diskMonitor` | Disk mount usage bars |
| [Network Monitor](networkMonitor/) | `networkMonitor` | Rolling network throughput chart |
| [Audio Switcher](audioSwitcher/) | `audioSwitcher` | Audio output switcher |
| [Quick Actions](quickActions/) | `quickActions` | Quick action toggles |
| [Digital Clock](digitalClock/) | `digitalClock` | Wide digital clock + date desktop widget |

## Per-plugin features

### CPU Core Visualizer
- One bar per CPU core with vivid or soft palette
- Adjustable bar width, gap, corner radius, and smoothing
- Configurable probe interval for fresh CPU stats
- Popout tooltip with per-core usage details

### GPU Monitor
- NVIDIA GPU telemetry (utilization, VRAM, clocks, power, encoder/decoder)
- Top GPU-memory processes in the popout
- Falls back to DMS metadata for non-NVIDIA GPUs

### Memory Monitor
- Memory usage bar with process listing, filtering, and sorting
- Shows total/used/available memory breakdown

### Disk Monitor
- Per-mount usage bars for selected disk partitions
- Selectable mount paths for the disk section

### Network Monitor
- Rolling chart with separate download/upload traces
- Configurable chart dimensions and history size

### Audio Switcher
- Clickable audio output button with current-device icon
- Sink selection and audio panel trigger

### Quick Actions
- Quick action toggles

### Digital Clock
- Wide horizontal digital clock + date, ideal for the corner of your desktop
- Toggles for seconds, AM/PM, and date
- Fixed font sizing: resizing the widget trims padding, not the digits
- Pin to bottom-right corner with adjustable margin (uses native layer-shell anchors, survives screen scale changes)

## Desktop widget support

Each plugin's `plugin.json` declares `"type": ["widget", "desktop-widget"]`. The QML widget auto-detects its host:

- **DankBar mode** — compact bar-aligned layout driven by `barConfig` (thickness, edge, font scale)
- **Desktop widget mode** — standalone widget with its own background, padding, and sizing (when `barConfig` is null)

DankMaterialShell handles the desktop widget window creation and positioning on niri.

## Install

Each plugin has its own `install.sh`. From a plugin directory:

```bash
cd cpuCoreVisualizer
chmod +x ./install.sh
./install.sh
```

Or install all plugins:

```bash
for dir in cpuCoreVisualizer gpuMonitor memoryMonitor diskMonitor networkMonitor audioSwitcher quickActions digitalClock; do
    cd "$dir"
    chmod +x ./install.sh
    ./install.sh
    cd ..
done
```

Then:

1. Open **DMS Settings -> Plugins**
2. Click **Scan for Plugins**
3. Enable the plugins you want
4. Add the plugin IDs to your DankBar widget list (e.g., `cpuCoreVisualizer`, `gpuMonitor`)
5. For desktop widgets, DMS will host them on niri automatically

Plugin IDs:
- `cpuCoreVisualizer`
- `gpuMonitor`
- `memoryMonitor`
- `diskMonitor`
- `networkMonitor`
- `audioSwitcher`

## Current limits

- top/bottom bars are the best-looking path right now
- left/right bars still use horizontal strips, but they now fill inward from the bar edge
- smoothness still depends on the host polling cadence
- rich GPU telemetry depends on `nvidia-smi`, but non-NVIDIA GPUs now fall back to DMS metadata and temperature when available

## Audio output button

- enable **Show Audio Output Button** in the plugin settings to add a clickable sink button to the bar
- the button icon reflects the active output type: monitor for HDMI/display sinks, headset for headphones, otherwise speaker
- left-click the button to open the audio panel, then choose an output from the source icons at the top
- leave both output selectors on **Auto cycle all outputs** to show every available sink in that selector row
- set **Preferred Output 1** and **Preferred Output 2** to limit the selector row to just those preferred devices
