#!/bin/zsh
# Launch the Debug build of MC Mus for macOS, wait for its window, optionally
# screenshot it, and quit it. Prints PID, window ID and log path.
set -euo pipefail

usage() {
    cat <<USAGE
usage: launch-mac-app.sh [--demo] [--build] [--screenshot PATH] [--keep] [--wait SECONDS]

  --demo             launch with the bundled demo library instead of ~/Music
  --build            run xcodebuild for macOS first
  --screenshot PATH  capture the main window to PATH (PNG) once it appears
  --keep             leave the app running (default: quit it before exiting)
  --wait SECONDS     how long to wait for the window (default 20)
USAGE
}

demo=0 build=0 keep=0 wait_seconds=20 screenshot=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --demo) demo=1 ;;
        --build) build=1 ;;
        --keep) keep=1 ;;
        --screenshot) screenshot="$2"; shift ;;
        --wait) wait_seconds="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

script_dir="${0:A:h}"
project_dir="${script_dir:h:h:h:h}"
cache_dir="${TMPDIR:-/tmp}/mcmus-launch-mac-app"
mkdir -p "$cache_dir"

if (( build )); then
    xcodebuild -project "$project_dir/mcmus.xcodeproj" -scheme app \
        -destination 'platform=macOS' -quiet build
fi

settings=$(xcodebuild -project "$project_dir/mcmus.xcodeproj" -scheme app \
    -destination 'platform=macOS' -showBuildSettings 2>/dev/null)
products_dir=$(print -r -- "$settings" | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/{print $2}')
product_name=$(print -r -- "$settings" | awk -F' = ' '/ FULL_PRODUCT_NAME =/{print $2}')
app="$products_dir/$product_name"
binary="$app/Contents/MacOS/${product_name%.app}"
if [[ ! -x "$binary" ]]; then
    echo "no build at $app; rerun with --build" >&2
    exit 1
fi

window_id_tool="$cache_dir/window-id"
if [[ ! -x "$window_id_tool" || "$script_dir/window-id.swift" -nt "$window_id_tool" ]]; then
    swiftc -O -o "$window_id_tool" "$script_dir/window-id.swift"
fi

# -ApplePersistenceIgnoreState must come before --demo: AppKit's argument
# parser otherwise swallows the pair and the app runs with no window.
args=(-ApplePersistenceIgnoreState YES)
(( demo )) && args+=(--demo)
log="$cache_dir/launch-$(date +%Y%m%d-%H%M%S)-$$.log"
"$binary" "${args[@]}" > "$log" 2>&1 &
app_pid=$!

window_id=""
for (( i = 0; i < wait_seconds * 2; i++ )); do
    sleep 0.5
    if ! kill -0 "$app_pid" 2>/dev/null; then
        echo "app exited early; log: $log" >&2
        cat "$log" >&2
        exit 1
    fi
    window_id=$("$window_id_tool" "$app_pid")
    [[ -n "$window_id" ]] && break
done
if [[ -z "$window_id" ]]; then
    echo "no window after ${wait_seconds}s (pid $app_pid); log: $log" >&2
    (( keep )) || kill "$app_pid" 2>/dev/null
    exit 1
fi

if [[ -n "$screenshot" ]]; then
    # Give the first library load a moment to populate the files panel.
    sleep 2
    screencapture -x -l "$window_id" "$screenshot"
fi

echo "pid=$app_pid window=$window_id log=$log"
[[ -n "$screenshot" ]] && echo "screenshot=$screenshot"
if (( keep )); then
    echo "app left running; quit with: kill $app_pid"
else
    kill "$app_pid"
fi
