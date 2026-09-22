#!/usr/bin/env bash
# Install GPU Monitor plugin into DankMaterialShell
set -euo pipefail

PLUGIN_DIR="$HOME/.config/DankMaterialShell/plugins/gpuMonitor"

echo "Installing GPU Monitor plugin..."
mkdir -p "$PLUGIN_DIR"
cp -r ../gpuMonitor/* "$PLUGIN_DIR/"

echo "GPU Monitor plugin installed to $PLUGIN_DIR"
echo "Open DMS Settings -> Plugins, click 'Scan for Plugins', enable 'GPU Monitor'."
echo "Then add 'gpuMonitor' to your SlopBar widget list or use as a desktop widget."
