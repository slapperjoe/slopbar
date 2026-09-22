#!/usr/bin/env bash
# Apply the desktop-widget corner-pin feature to the system DesktopPluginWrapper.
#
# This patches the DMS-installed wrapper so desktop widgets can be pinned to a
# screen corner. Pinning uses NATIVE layer-shell anchors (right+bottom, or any
# corner), so the compositor keeps the widget glued to the corner through ANY
# output scale / DPR / geometry change — it is not a coordinate recompute.
#
# The pin itself is enabled per-instance from the plugin's settings
# (digitalClock -> "Pin to bottom-right corner").
#
# NOTE: /usr/share/quickshell/dms is owned by the dms-shell package, so this
# patch is overwritten by dms-shell package updates. Re-run this script after
# any dms-shell upgrade (or upstream the feature).
set -euo pipefail

WRAPPER=/usr/share/quickshell/dms/Modules/Plugins/DesktopPluginWrapper.qml
PATCH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$PATCH_DIR/desktop-widget-corner-pin.patch"
BACKUP="$WRAPPER.bak-cornerpin"

if [[ ! -f "$WRAPPER" ]]; then
    echo "error: $WRAPPER not found (wrong DMS layout?)" >&2
    exit 1
fi

# Native-anchor marker: the current patch adds these booleans.
already_native() {
    grep -q 'readonly property bool anchorRight' "$WRAPPER"
}
# Older coordinate-recompute version (superseded).
has_old_coordinate_version() {
    grep -q 'cfg.pinToCorner === true' "$WRAPPER" && ! already_native
}

if already_native; then
    echo "Corner-pin patch (native anchors) already applied to $WRAPPER"
else
    if has_old_coordinate_version; then
        # Upgrade path: the previous coordinate-recompute patch is applied.
        # Restore pristine from the first-run backup, then apply the native one.
        if [[ -f "$BACKUP" ]]; then
            echo "Found older coordinate-based version — restoring pristine from $BACKUP"
            cp "$BACKUP" "$WRAPPER"
        else
            echo "error: older patch applied but no pristine backup at $BACKUP" >&2
            echo "  Reinstall dms-shell to restore the original wrapper, then re-run." >&2
            exit 1
        fi
    else
        cp "$WRAPPER" "$BACKUP"
        echo "Backed up wrapper to $BACKUP"
    fi
    patch -p1 -d /usr/share/quickshell/dms < "$PATCH"
    echo "Applied corner-pin patch (native layer-shell anchors)"
fi

# Force QML recompilation of the shell (soft reload can reuse compiled QML).
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/qmlcache" 2>/dev/null || true

# Restart the shell so the wrapper recompiles.
dms restart 2>/dev/null || {
    pkill -f "qs -p /usr/share/quickshell/dms" || true
}

cat <<EOF

Applied. To pin the Digital Clock (or any desktop widget) to a corner:
  DMS Settings -> Desktop Widgets -> open the widget -> enable
  "Pin to bottom-right corner" (optional "Corner Margin").

Also reinstall the plugin so the new settings appear:
  cd dankbar-cpu-core-visualizer && ./install.sh --plugin digitalClock
EOF
