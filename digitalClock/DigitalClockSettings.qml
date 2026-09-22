import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "digitalClock"

    ToggleSetting {
        settingKey: "showSeconds"
        label: "Show Seconds"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showAmPm"
        label: "Show AM/PM"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showDate"
        label: "Show Date"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: "Background Opacity"
        defaultValue: 55
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "pinToCorner"
        label: "Pin to bottom-right corner"
        description: "Keep the widget pinned to the corner with a fixed margin, even when screen scale changes"
        defaultValue: false
    }

    SliderSetting {
        settingKey: "cornerMargin"
        label: "Corner Margin"
        description: "Distance from the corner edge (px)"
        defaultValue: 60
        minimum: 0
        maximum: 400
        unit: "px"
    }
}
