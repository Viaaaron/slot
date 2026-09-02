#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
APP_SOURCE="$PROJECT_DIR/build/Slot.app"
APP_DESTINATION="/Applications/Slot.app"
CURRENT_USER_NAME="$(id -un)"
CURRENT_USER_HOME="$(dscl . -read "/Users/$CURRENT_USER_NAME" NFSHomeDirectory | awk '{print $2}')"
LAUNCH_AGENTS_DIR="$CURRENT_USER_HOME/Library/LaunchAgents"
LAUNCH_AGENT_SOURCE="$PROJECT_DIR/Resources/com.viaaaron.Slot.plist"
LAUNCH_AGENT_DESTINATION="$LAUNCH_AGENTS_DIR/com.viaaaron.Slot.plist"
GUI_DOMAIN="gui/$(id -u)"

"$PROJECT_DIR/build.sh"

if [[ -w /Applications ]]; then
  ditto "$APP_SOURCE" "$APP_DESTINATION"
else
  sudo ditto "$APP_SOURCE" "$APP_DESTINATION"
fi

mkdir -p "$LAUNCH_AGENTS_DIR"
cp "$LAUNCH_AGENT_SOURCE" "$LAUNCH_AGENT_DESTINATION"

if launchctl print "$GUI_DOMAIN/com.viaaaron.Slot" >/dev/null 2>&1; then
  launchctl bootout "$GUI_DOMAIN/com.viaaaron.Slot"
fi
launchctl bootstrap "$GUI_DOMAIN" "$LAUNCH_AGENT_DESTINATION"

open -g "$APP_DESTINATION"
echo "Slot is installed. Grant Accessibility access when macOS prompts."

