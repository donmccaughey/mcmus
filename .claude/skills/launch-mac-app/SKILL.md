---
name: launch-mac-app
description: Launch the MC Mus macOS Debug build from the command line, wait for its window, screenshot it, and quit it cleanly, in normal or --demo mode. Use this whenever you need to run, launch, open, smoke-test, or screenshot the Mac app to verify a change, including when the `run` skill or a plan's verification step calls for running the app. Encodes launch-flag ordering and window-lookup pitfalls that otherwise make a working build look hung.
allowed-tools: Bash(.claude/skills/launch-mac-app/scripts/launch-mac-app.sh:*), Bash(xcodebuild:*), Bash(screencapture:*), Bash(kill:*), Bash(pgrep:*)
---

Use the bundled script rather than hand-rolling `open` and AppleScript. It
handles every pitfall listed below.

```bash
.claude/skills/launch-mac-app/scripts/launch-mac-app.sh [--demo] [--root PATH] [--build] [--screenshot PATH] [--keep] [--wait SECONDS]
```

Typical verification of a change, both library modes:

```bash
S=<scratchpad directory>
.claude/skills/launch-mac-app/scripts/launch-mac-app.sh --build --screenshot "$S/real.png"
.claude/skills/launch-mac-app/scripts/launch-mac-app.sh --demo --screenshot "$S/demo.png"
```

Then view each PNG with the Read tool. The script quits the app before it
exits unless `--keep` is given, and prints the PID so only that instance is
ever killed. It exits non-zero, with the app's stderr, if the process dies or
no window appears within the wait.

Run `--build` once per source change. Without it the script uses whatever
Debug build is already in DerivedData, which may be stale.

## Why the script does what it does

Each of these cost real time when discovered, so do not work around the
script in ways that reintroduce them.

- **Flag order.** `-ApplePersistenceIgnoreState YES` goes before `--demo`.
  With `--demo` first, AppKit's argument parser swallows the pair: the process
  stays alive with an idle main thread and never shows a window. It looks like
  a hang or a regression in the code under test and is neither.
- **Window lookup.** System Events (`osascript`) needs an Accessibility grant
  and blocks forever on the permission prompt when run unattended. The script
  compiles a tiny Swift tool around `CGWindowListCopyWindowInfo`, which needs
  no permission, and polls it by PID.
- **Process name.** The product is `MC Mus`, with a space, not `mcmus`.
  `pkill -x mcmus` and `tell process "mcmus"` silently match nothing; quote
  the name: `pkill -x "MC Mus"`, `tell process "MC Mus"`.
- **Launch the binary, not the bundle.** Running
  `MC Mus.app/Contents/MacOS/MC Mus` directly gives the PID as `$!` and captures
  stderr to a log. `open -n` loses both and needs a `pgrep` that may pick up
  the user's own running copy of the app.
- **Screenshots by window ID.** `screencapture -l <id>` captures only that
  window. Never capture the whole screen.
- **Persistence state.** `-ApplePersistenceIgnoreState YES` stops NSWindow
  state restoration from replaying saved state. The main window's size is
  kept by frame autosave instead (key `NSWindow Frame main`), which the flag
  does not touch. To check the first-launch size, delete the key first and
  read it back through cfprefsd, not the plist file, which lags:

  ```bash
  dom=~/Library/Containers/cc.donm.mcmus/Data/Library/Preferences/cc.donm.mcmus
  defaults delete "$dom" "NSWindow Frame main"
  defaults read "$dom" "NSWindow Frame main"
  ```

## Checking the result

- Normal mode: the Files panel lists folders from the music root chosen in
  Settings (`~/Music` on a fresh install).
- With `--root PATH` (Debug builds only outside `~/Music`): the Files panel
  lists folders from PATH, and Settings shows PATH. A missing PATH falls back
  to normal mode; `--demo` wins over `--root`.
- Demo mode: the Files panel lists artist folders from the bundled
  `demo-data.json` (starting with "3 Doors Down").
- Either mode with an empty Files panel after a few seconds means the load
  result carried an error; check the log path the script prints.

If the user already has MC Mus open, leave it alone. The script only ever
signals the PID it launched.

## Driving the launched app

The UI is programmatic AppKit, so System Events works on it directly once
the process is addressed by pid, never by name (the user's own copy is
usually running too):

- `tell (first process whose unix id is <pid>)` for menus, AX queries and
  `click button "Play"`; real `NSButton`s fire from an AX click.
- The Settings window's controls sit directly in `window "MC Mus Settings"`:
  `static text 2` is the path, `button "Choose…"` the button.
- `NSRunningApplication.activate()` on the pid orders the main window in
  front of an open Settings window; reopen Settings from the menu before
  clicking in it.
- `screencapture -l <window id>` works for any of the pid's windows; list
  them with `CGWindowListCopyWindowInfo` (the skill's `window-id` tool only
  prints the first one).
- To see every view frame in the running app:
  `lldb -p <pid> --batch -o 'expr -l objc -O -- [[[[NSApplication sharedApplication] windows][0] contentView] _subtreeDescription]' -o detach -o quit`.
