#!/bin/zsh
# Launch the Debug build of MC Mus on an iOS simulator, set the orientation,
# optionally screenshot the device, and terminate the app. Prints the device
# UDID, the app's PID, the log path, and the simulator window's frame.
set -euo pipefail

default_device="iPhone 16e"
default_os="18.4"
bundle_id="cc.donm.mcmus"

usage() {
    cat <<USAGE
usage: launch-ios-app.sh [--demo] [--build] [--screenshot PATH] [--landscape]
                         [--udid UDID] [--keep] [--wait SECONDS]

  --demo             launch with the bundled demo library
  --build            run xcodebuild for the simulator first
  --screenshot PATH  capture the device screen to PATH (PNG), upright, after launch
  --landscape        rotate the device to landscape (default: portrait)
  --udid UDID        simulator to use (default: the iOS $default_os $default_device)
  --keep             leave the app running (default: terminate it before exiting)
  --wait SECONDS     how long to let the app settle before the screenshot (default 3)
USAGE
}

demo=0 build=0 keep=0 landscape=0 wait_seconds=3 screenshot="" udid=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --demo) demo=1 ;;
        --build) build=1 ;;
        --keep) keep=1 ;;
        --landscape) landscape=1 ;;
        --screenshot) screenshot="$2"; shift ;;
        --udid) udid="$2"; shift ;;
        --wait) wait_seconds="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

script_dir="${0:A:h}"
project_dir="${script_dir:h:h:h:h}"
cache_dir="${TMPDIR:-/tmp}/mcmus-launch-ios-app"
mkdir -p "$cache_dir"

resolve_device() {
    xcrun simctl list -j devices available \
        | python3 -I "$script_dir/resolve-device.py" "$1" "$default_device" "$default_os"
}

if ! device=$(resolve_device "$udid"); then
    echo "no available simulator for ${udid:-iOS $default_os $default_device}" >&2
    exit 1
fi
udid="${device%%$'\t'*}"
device_name="${${device#*$'\t'}%%$'\t'*}"
os_version="${device##*$'\t'}"
# Simulator.app names the window "<device> – <OS>" with an en dash.
window_name="$device_name – iOS $os_version"

simulator_window() {
    osascript -e "tell application \"System Events\" to tell process \"Simulator\" to get $1 of window \"$window_name\"" 2>/dev/null | tr -d ' '
}

xcrun simctl bootstatus "$udid" -b > /dev/null
pgrep -xq Simulator || open -a Simulator
# Simulator.app opens a window for every booted device; wait for this one.
for (( i = 0; i < 40; i++ )); do
    [[ -n "$(simulator_window size)" ]] && break
    sleep 0.5
done

# The arch keeps xcodebuild from warning about the Rosetta destination.
destination="platform=iOS Simulator,id=$udid,arch=$(uname -m)"
if (( build )); then
    xcodebuild -project "$project_dir/mcmus.xcodeproj" -scheme app \
        -destination "$destination" -quiet build
fi

settings=$(xcodebuild -project "$project_dir/mcmus.xcodeproj" -scheme app \
    -destination "$destination" -showBuildSettings 2>/dev/null)
products_dir=$(print -r -- "$settings" | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/{print $2}')
product_name=$(print -r -- "$settings" | awk -F' = ' '/ FULL_PRODUCT_NAME =/{print $2}')
app="$products_dir/$product_name"
if [[ ! -d "$app" ]]; then
    echo "no build at $app; rerun with --build" >&2
    exit 1
fi

orientation_tool="$cache_dir/screen-orientation"
if [[ ! -x "$orientation_tool" || "$script_dir/screen-orientation.swift" -nt "$orientation_tool" ]]; then
    swiftc -O -o "$orientation_tool" "$script_dir/screen-orientation.swift"
fi

# A fresh launch starts with an empty queue; a running copy would keep its.
xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
xcrun simctl install "$udid" "$app"

args=()
(( demo )) && args+=(--demo)
launch_time=$(date '+%Y-%m-%d %H:%M:%S')
launch_output=$(xcrun simctl launch "$udid" "$bundle_id" "${args[@]}")
app_pid="${launch_output##*: }"

# The orientation the app is laid out in, read from the screen itself, since
# simctl cannot report it and the window's shape alone cannot tell portrait
# from upside down.
app_orientation() {
    local probe="$cache_dir/orientation-probe.png"
    xcrun simctl io "$udid" screenshot "$probe" > /dev/null 2>&1
    "$orientation_tool" "$probe"
}

window_is_landscape() {
    local size=$(simulator_window size)
    (( ${size%%,*} > ${size##*,} ))
}

# Simulator.app has no scripting interface; rotation is its ⌘← / ⌘→ menu
# shortcuts, sent to the raised window of this device so another booted
# device's window does not receive them.
rotate() {
    osascript > /dev/null <<APPLESCRIPT
tell application "Simulator" to activate
tell application "System Events" to tell process "Simulator"
    perform action "AXRaise" of window "$window_name"
    key code $1 using command down
end tell
APPLESCRIPT
    sleep 2
}
rotate_left() { rotate 123 }
rotate_right() { rotate 124 }

# Rotate Right cycles portrait → landscape right → upside down → landscape
# left; Rotate Left is the reverse. iPhone apps refuse upside down and keep
# their last landscape layout there while the window turns portrait-shaped,
# so that state is left by rotating back toward the landscape the app shows.
if (( landscape )); then target=landscape-left; else target=portrait; fi
sleep 1
for (( i = 0; i < 6; i++ )); do
    orientation=$(app_orientation)
    case "$orientation" in
        unknown) sleep 1 ;;
        portrait) [[ "$target" == portrait ]] && break; rotate_left ;;
        landscape-left) [[ "$target" == landscape-left ]] && window_is_landscape && break; rotate_right ;;
        landscape-right) rotate_left ;;
    esac
done
if [[ "$orientation" != "$target" ]] || { (( landscape )) && ! window_is_landscape; }; then
    echo "could not rotate $window_name to $target (now $orientation); is osascript granted Accessibility?" >&2
    exit 1
fi

sleep "$wait_seconds"
# `simctl launch --stderr` never creates its file, so the app's errors and
# Auto Layout complaints are pulled from the unified log instead.
log="$cache_dir/launch-$(date +%Y%m%d-%H%M%S)-$$.log"
xcrun simctl spawn "$udid" log show --start "$launch_time" --style compact \
    --predicate "process == \"${product_name%.app}\" AND (messageType == error OR messageType == fault OR eventMessage CONTAINS \"constraint\")" \
    2>/dev/null | grep -v '^Timestamp' > "$log" || true
if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "app exited early (pid $app_pid); log: $log" >&2
    cat "$log" >&2
    exit 1
fi

if [[ -n "$screenshot" ]]; then
    xcrun simctl io "$udid" screenshot "$screenshot" > /dev/null 2>&1
    # simctl writes the framebuffer in physical portrait orientation.
    (( landscape )) && sips -r 270 "$screenshot" > /dev/null
fi

echo "udid=$udid pid=$app_pid log=$log window=$(simulator_window position),$(simulator_window size)"
[[ -n "$screenshot" ]] && echo "screenshot=$screenshot"
if (( keep )); then
    echo "app left running; quit with: xcrun simctl terminate $udid $bundle_id"
else
    xcrun simctl terminate "$udid" "$bundle_id"
fi
