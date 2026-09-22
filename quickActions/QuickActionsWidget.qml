import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    property string selectedDisplay: "auto"
    property var connectedDisplays: []
    property string currentRotation: "normal"
    property bool lidSleepEnabled: true
    property int lidInhibitorPid: 0

    function fetchDisplays() {
        Proc.runCommand("displays", ["sh", "-c", "niri msg --json outputs 2>/dev/null"],
            function(output, exitCode) {
                if (exitCode !== 0 || !output) {
                    root.connectedDisplays = [];
                    return;
                }
                try {
                    var data = JSON.parse(output);
                    var displays = [];
                    for (var key in data) {
                        displays.push(key);
                    }
                    root.connectedDisplays = displays;
                    if (displays.length > 0 && root.selectedDisplay === "auto") {
                        root.selectedDisplay = displays[0];
                        pluginService.savePluginData("quickActions", "selectedDisplay", displays[0]);
                    }
                } catch (e) {
                    console.error("Failed to parse niri outputs:", e);
                    root.connectedDisplays = [];
                }
            }, 50, 5000);
    }

    function fetchRotationState(display) {
        if (!display) display = root.selectedDisplay;
        Proc.runCommand("rotation", ["sh", "-c", "niri msg --json outputs 2>/dev/null"],
            function(output, exitCode) {
                if (exitCode !== 0 || !output) return;
                try {
                    var data = JSON.parse(output);
                    if (data[display]) {
                        var rot = data[display].logical.transform;
                        root.currentRotation = rot || "normal";
                    }
                } catch (e) {
                    console.error("Failed to parse rotation state:", e);
                }
            }, 50, 5000);
    }

    function rotateDisplay(transform) {
        var display = root.selectedDisplay;
        if (!display || display === "auto") {
            if (root.connectedDisplays.length > 0) {
                display = root.connectedDisplays[0];
                root.selectedDisplay = display;
                pluginService.savePluginData("quickActions", "selectedDisplay", display);
            } else {
                ToastService.error("No display", "No connected displays found.");
                return;
            }
        }
        Proc.runCommand("rotate", ["sh", "-c", "niri msg output " + display + " transform " + transform],
            function(output, exitCode) {
                if (exitCode !== 0) {
                    console.error("Failed to rotate display:", output);
                    ToastService.error("Rotation failed", "Could not rotate display.");
                } else {
                    ToastService.success("Display rotated", "Rotated " + display + " to " + transform);
                    root.fetchRotationState(display);
                }
            }, 50, 5000);
    }

    function rotateLeft() {
        root.rotateDisplay("90");
    }

    function rotateRight() {
        root.rotateDisplay("270");
    }

    function rotateNormal() {
        root.rotateDisplay("normal");
    }

    function rotateInverted() {
        root.rotateDisplay("180");
    }

    function enableLidSleep() {
        if (root.lidInhibitorPid > 0) {
            Proc.runCommand("uninhibit_lid", ["sh", "-c", "kill " + root.lidInhibitorPid + " 2>/dev/null"]);
            root.lidInhibitorPid = 0;
        }
        root.lidSleepEnabled = true;
        pluginService.savePluginData("quickActions", "lidSleepEnabled", true);
        ToastService.success("Lid sleep", "Lid sleep enabled");
    }

    function disableLidSleep() {
        Proc.runCommand("inhibit_lid", ["sh", "-c", "systemd-inhibit --what=handle-lid-switch --who='SlopBar QuickActions' --why='User disabled lid sleep' sleep infinity & echo $!"],
            function(output, exitCode) {
                if (exitCode !== 0 || !output) {
                    ToastService.error("Failed", "Could not disable lid sleep. Is systemd-inhibit available?");
                    root.lidSleepEnabled = true;
                    pluginService.savePluginData("quickActions", "lidSleepEnabled", true);
                    return;
                }
                root.lidInhibitorPid = parseInt(output);
                if (!root.lidInhibitorPid || root.lidInhibitorPid <= 0) {
                    ToastService.error("Failed", "Invalid inhibitor PID: " + output);
                    root.lidSleepEnabled = true;
                    pluginService.savePluginData("quickActions", "lidSleepEnabled", true);
                    return;
                }
            });
        root.lidSleepEnabled = false;
        pluginService.savePluginData("quickActions", "lidSleepEnabled", false);
        ToastService.success("Lid sleep", "Lid sleep disabled — laptop stays awake on lid close");
    }

    function toggleLidSleep() {
        if (root.lidSleepEnabled) {
            root.disableLidSleep();
        } else {
            root.enableLidSleep();
        }
    }

    function restoreLidInhibitor() {
        if (root.lidInhibitorPid > 0) return;
        Proc.runCommand("inhibit_lid_restore", ["sh", "-c", "systemd-inhibit --what=handle-lid-switch --who='SlopBar QuickActions' --why='User disabled lid sleep' sleep infinity & echo $!"],
            function(output, exitCode) {
                if (exitCode === 0 && output) {
                    var pid = parseInt(output);
                    if (pid > 0) root.lidInhibitorPid = pid;
                }
            });
    }

    Component.onCompleted: {
        root.selectedDisplay = pluginData["selectedDisplay"] || "auto";
        var savedLidState = pluginData["lidSleepEnabled"];
        root.lidSleepEnabled = savedLidState !== undefined ? savedLidState : true;
        if (!root.lidSleepEnabled) root.restoreLidInhibitor();
        root.fetchDisplays();
    }

    Component.onDestruction: {
    }

    Timer {
        id: settingsPoller
        interval: 250
        running: true
        repeat: true
        onTriggered: root.reloadSettings()
    }

    function reloadSettings() {
        root.selectedDisplay = pluginData["selectedDisplay"] || "auto";
        var savedLidState = pluginData["lidSleepEnabled"];
        if (savedLidState !== undefined) root.lidSleepEnabled = savedLidState;
    }

    horizontalBarPill: Component {
        MouseArea {
            implicitWidth: hContentRow.implicitWidth
            implicitHeight: hContentRow.implicitHeight
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.pillRightClickAction()
                } else {
                    root.pillClickAction()
                }
            }

            Row {
                id: hContentRow
                spacing: -4

                DankIcon {
                    name: "bolt"
                    size: Theme.iconSize - 6
                    color: Theme.widgetTextColor
                    filled: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        MouseArea {
            implicitWidth: vContentRow.implicitWidth
            implicitHeight: vContentRow.implicitHeight
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.pillRightClickAction()
                } else {
                    root.pillClickAction()
                }
            }

            Row {
                id: vContentRow
                spacing: -4

                DankIcon {
                    name: "bolt"
                    size: Theme.iconSize - 6
                    color: Theme.widgetTextColor
                    filled: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    pillClickAction: function() {
        root.openPopout();
    }

    pillRightClickAction: function(posX, posY, posWidth, sectionName, currentScreen) {
        root.openPopout();
    }

    function openPopout() {
        root.fetchDisplays();
        var popout = null, pill = null;
        for (var i = 0; i < root.children.length; i++) {
            var child = root.children[i];
            if (typeof child.setTriggerPosition === "function") popout = child;
            if (typeof child.mapToItem === "function" && child.width !== undefined && child.width > 0 && typeof child.setTriggerPosition !== "function") pill = child;
        }
        if (popout && pill) {
            var globalPos = pill.mapToItem(null, 0, 0);
            var screen = root.parentScreen || Screen;
            var pos = SettingsData.getPopupTriggerPosition(globalPos, screen, root.barThickness, pill.width, 8, 0, null);
            popout.setTriggerPosition(pos.x, pos.y, pos.width, root.section, screen, 0, root.barThickness, 8, null);
            popout.toggle();
            if (root.selectedDisplay !== "auto") {
                root.fetchRotationState(root.selectedDisplay);
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "Quick Actions"
            detailsText: "Display rotation and system shortcuts"
            showCloseButton: false

            Column {
                width: parent.width
                anchors.margins: 8
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.spacingM

                // ── Display Rotation ─────────────────────
                StyledText {
                    text: "Display Rotation"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    // Rotate Left
                    Rectangle {
                        width: (parent.width - 2 * Theme.spacingS) / 3
                        height: 56
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        anchors.verticalCenter: parent.verticalCenter

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "rotate_left"
                                size: 24
                                color: Theme.primary
                                filled: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: "Left 90°"
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.rotateLeft();
                                popout.closePopout();
                            }
                        }
                    }

                    // Rotate Right
                    Rectangle {
                        width: (parent.width - 2 * Theme.spacingS) / 3
                        height: 56
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        anchors.verticalCenter: parent.verticalCenter

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "rotate_right"
                                size: 24
                                color: Theme.primary
                                filled: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: "Right 90°"
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.rotateRight();
                                popout.closePopout();
                            }
                        }
                    }

                    // Rotate Normal
                    Rectangle {
                        width: (parent.width - 2 * Theme.spacingS) / 3
                        height: 56
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        anchors.verticalCenter: parent.verticalCenter

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "screen_rotation"
                                size: 24
                                color: Theme.primary
                                filled: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: "Normal"
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.rotateNormal();
                                popout.closePopout();
                            }
                        }
                    }
                }

                // Current rotation indicator
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.centerIn: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "monitor"
                            size: 16
                            color: Theme.surfaceVariantText
                            filled: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.selectedDisplay
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "— " + root.currentRotation + " rotation"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // ── Lid Sleep Toggle ─────────────────────
                StyledText {
                    text: "Lid Sleep"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "laptop"
                            size: 24
                            color: root.lidSleepEnabled ? Theme.primary : "#FF5252"
                            filled: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Lid Sleep"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: root.lidSleepEnabled ? "ON" : "OFF"
                        color: root.lidSleepEnabled ? "#4CAF50" : "#FF5252"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.toggleLidSleep();
                            popout.closePopout();
                        }
                    }
                }
            }
        }
    }
    popoutWidth: 340
    popoutHeight: 0
}
