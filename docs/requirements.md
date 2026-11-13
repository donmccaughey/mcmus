# Requirements

This document contains requirements for "MC Mus", a cross-platform, offline
music player application. Requirements in this document are written in
[EARS][], the "easy approach to requirements syntax".

[EARS]: https://github.com/donmccaughey/ears/blob/main/ears-cheat-sheet.md

This document uses the additional pattern ON for requirements that vary
according to operating system.

    On <operating system>,
    the <system name> shall <system response>.


# Overview

MC Mus shall run on macOS and iOS; where "iOS" includes both iPhone and iPad
form factors and both iOS and iPadOS operating systems.


# Project configuration

MC Mus shall use Xcode 26 and be built on macOS 15 Sequoia.

On macOS, MC Mus shall target macOS 15 Sequoia or later.

On iOS, MC Mus shall target iOS 18 (including iPadOS 18) or later.

MC Mus shall set the app category in Xcode to "Music".

MC Mus shall use `clang-format` to apply a consistent format to the project's
Objective-C code.

MC Mus shall use the Objective-C language and follow the style guidelines in
[Objective-C Style](objective-c-style.md).

On macOS, MC Mus shall use the AppKit framework for its user interface, rather
than SwiftUI or Mac Catalyst.

On macOS, MC Mus shall create all windows, views and menus programmatically and
shall not use nibs or storyboards.

On iOS, MC Mus shall use the UIKit framework for its user interface, rather
than SwiftUI.

On iOS, MC Mus shall create all scenes, windows, views and view controllers
programmatically and shall not use nibs or storyboards.

On macOS, MC Mus shall use the App Sandbox so that it can be distributed through
the Mac App Store.

On macOS, MC Mus shall request only these sandbox entitlements: read-only access
to user-selected files, app-scoped security bookmarks and read-only access to
the user's Music folder.

MC Mus shall use only APIs available on the minimum deployment targets.

On iOS, MC Mus shall declare support for all four interface orientations:
portrait, portrait upside-down, landscape left and landscape right.


# General definitions

A **localized display name** is the name of a directory or file obtained from
macOS or iOS API calls like `FileManager.displayName(atPath:)`, which may differ
from the actual filesystem name of the directory or file. See the [Localized
Display Name](localized-display-name-2026-10.md) document for details.


# Project organization

The MC Mus project shall place source files for artwork and other media in the
`assets/` subdirectory.

The MC Mus project shall place documentation files in the `docs/` subdirectory.

The MC Mus project shall place script files in the `scripts/` subdirectory.

The MC Mus project shall place project source code in the `src/` subdirectory.


## Third-party code

The MC Mus project shall place third party source code in the `lib/`
subdirectory.

The MC Mus project shall "vendor" third party source code in the `lib/`
subdirectory.

The MC Mus project shall keep a software bill of materials (SBOM) in the file
`bom.md`, with the source URL and version of each third party source code
package.


## Code organization

The MC Mus project shall organize code into static libraries that have low
coupling and high cohesion wherever practical.

The MC Mus project shall place each class, struct, function or set of related
functions that represent a significant application concept in its own code file;
Objective-C categories and extensions, C functions and small classes and structs
may share a code file when they have a single consumer.

The MC Mus project shall minimize the declarations that appear in header files
wherever practical.

The MC Mus project shall use static (internal) linkage for symbols wherever
practical.

The MC Mus project shall add the prefix `-iOS` or `-macOS` to the base name of
code files that serve the same purpose in the app but cannot be shared between
the iOS and macOS versions of the app. For example, the `MainViewController`
class in iOS inherits from `UIViewController` while in macOS it inherits from
`NSViewController`.

The MC Mus project shall create [wrapper interfaces](wrappers-for-testing.md)
for system services that are difficult to test in isolation, such as the file
system, network, audio playback, time and random number generation.


## Libraries

The MC Mus project shall place wrapper interfaces and their real implementations
in the **wrappers** library, with code and unit tests placed in the
`src/wrappers/` subdirectory.

The wrappers library shall not depend on any other library in the MC Mus
project.

The wrappers unit tests shall depend on the wrappers-fakes library.

The MC Mus project shall place the fake implementations of wrapper interfaces,
and test helpers in the **wrappers-fakes** library, with code and unit tests
placed in the `src/wrappers/` subdirectory next to the wrapper interfaces and
real implementations.

The wrappers-fakes library shall depend on the wrappers library.

The MC Mus project shall place model code in the **model** library, with code
and unit tests placed in the `src/model/` subdirectory.

The model library shall depend on the wrappers library; model unit tests shall
also depend on the wrappers-fakes library.

The MC Mus project shall place code for file system snapshots in the
**snapshot** library, with code and unit tests placed in the `src/snapshot/`
subdirectory.

The snapshot library shall depend on the wrappers library; snapshot unit tests
shall also depend on the wrappers-fakes library.

The MC Mus project shall place CSV parsing and formatting code in the **csv**
library, with code and unit tests placed in the `src/csv/` subdirectory.

The csv library shall not depend on any other library in the MC Mus project.

The MC Mus project shall pace code for file sharing in the **file-sharing** library, with code and unit tests placed in the `src/file-sharing/` subdirectory.

The file-sharing library shall depend on the wrappers, model and snapshot
libraries; file-sharing unit tests shall also depend on the wrappers-fakes
library.

The MC Mus project shall place **app** code, configuration, assets and
corresponding unit tests in the `src/app/` subdirectory.

The MC Mus project shall organize user interface code around major UI elements
and/or features. The primary files panel code shall live in `src/app/files/`.
Main view and main window code shall live in `src/app/main/`. The primary queue
panel code shall live in `src/app/queue/`. The settings dialog code shall live
in `src/app/settings/`. Views, controls and UI utility code shared across major
UI elements or feature shall live in `src/app/components/`.


# System service wrappers

The **file system wrapper** shall wrap general file system information and
operations.

On macOS, the file system wrapper shall wrap security-scoped bookmark creation,
resolution and access.

The **preferences wrapper** shall wrap user defaults and other settings.


## Audio wrapper

The **audio library** is collectively the set of system audio APIs used to
implement playback.

The audio library shall support gapless playback of `.mp3` and `.m4a` files.

The **audio wrapper** shall wrap the audio library, exposing high level
operations in the application domain.


## Demo wrappers

In demo mode, MC Mus shall wrap the file system wrapper in the **demo file
system wrapper** and the audio wrapper in the **demo audio wrapper**.

The demo file system wrapper shall be created from the contents of the
`demo-data.json` file and a wrapped file system wrapper. The first JSON object
in the file with member `"type"="directory"` is the **demo root directory**;
its `"name"` member is the path of the directory, or `/` when absent.

The demo file system wrapper shall list the contents of directories inside the
demo root directory and report information about them, using all applicable
rules on the file and directory names and ignoring rules that only apply to
real directories and files: entries without names and entries whose names begin
with `.` shall be omitted; directories whose names end with the `.itlp`
extension shall be reported as packages.

The demo file system wrapper shall report the demo root directory as the music
directory.

On macOS, the demo file system wrapper shall resolve a saved security-scoped
bookmark to the demo root directory and shall grant access to the demo root
directory without the wrapped file system wrapper. A bookmark created through
the demo file system wrapper shall resolve to its own directory, so that a music
root directory chosen in demo mode is loaded from the real file system.

On iOS, the demo file system wrapper shall report the parent of the demo root
directory as the application support directory and shall create the demo root
directory and exclude it from backup without the wrapped file system wrapper.
Because the iOS music root directory is the `Music` subdirectory of the
application support directory, the demo root directory shall be named `Music`.

The demo file system wrapper shall forward all other operations, and operations
on paths outside the demo root directory, to the wrapped file system wrapper.

If the demo data cannot be parsed or contains no directory object, the demo file
system wrapper shall report the error from the operations used to locate the
music root directory.

The demo audio wrapper shall be created from the URL of the `demo-track.mp3`
file and a wrapped audio wrapper. The demo audio wrapper shall pass the demo
track URL to the wrapped audio wrapper in place of every track URL, so that
every demo track is playable, and shall forward all other operations.


# Model

The **music root directory** is the directory on the local filesystem that
MC Mus searches for music files.

On macOS, MC Mus shall save the music root directory in user defaults as a
security-scoped bookmark.

On macOS, when the saved bookmark resolves and can be accessed, MC Mus shall
start accessing the security-scoped music root directory and keep it accessible
for as long as it is the music root directory.

On macOS, when the saved bookmark resolves but is stale, MC Mus shall replace
the saved bookmark with a fresh one.

On macOS, when no bookmark is saved or the saved bookmark does not resolve or
cannot be accessed, MC Mus shall use the system music directory for the current
user as the music root directory without saving a bookmark.

On iOS, MC Mus shall use the `Music/` subdirectory of the standard application
support directory as the music root directory, creating it on launch if it does
not exist.

On iOS, MC Mus shall exclude the music root directory from backup.

A **music directory** is a directory under the music root directory that is not
hidden and is not a package.

A **music file** is a regular file with an `.mp3` or `.m4a` extension (case
insensitive) that is not hidden.


## Music library

A **music library** is an in-memory tree data structure consisting of folders
(branch nodes) and tracks (leaf nodes) that correspond to music directories and
music files in the music root directory, with a root folder for the music root
directory itself, one folder for each music directory and one track for each
music file. A music library has one property: **root folder**.

An **empty music library** is a music library where the root folder is an empty
folder.

A music library shall have a no argument initializer that creates an empty music
library.

A music library shall have a one argument initializer that takes a folder to set
as the root folder.

A music library shall have an **is empty** read-only calculated property that is
true when the root folder has no children and false otherwise.

A **load result** is the value returned by a load function. A load result has
these properties: **library** is the music library that was loaded; **errors**
is the list of errors encountered while loading, which is empty when loading
succeeded completely.

MC Mus shall have a **load music library** function that is called with the path
of the music root directory.

The load music library function shall create a root folder with folders and
tracks created by walking the given music root directory and return a load
result containing a new music library initialized with the root folder.

The load music library function shall omit any folder from the tree (other than
the root folder) which has no tracks that are direct children or descendents.

If it cannot list the music root directory, the load music library function
shall return a load result containing an empty music library and the error.

If it encounters an error while walking a subdirectory or file, the load music
library function shall add the error to the load result and continue walking.

MC Mus shall have a **load track metadata** function that is called with a list
of tracks and returns a list of track metadata, in the order of the given
tracks, along with the list of errors encountered, which is empty when loading
succeeded completely.

If it cannot read the size of a track's music file, the load track metadata
function shall add the error to the list of errors, omit that track from the
returned track metadata and continue with the next track.

If it cannot calculate the hash of a track's music file, the load track metadata
function shall add the error to the list of errors and return track metadata for
that track with a file hash of zero.


## Folder

A **folder** is a branch node of the music library that corresponds to a
directory. A folder has these properties: **path** is the absolute path of the
corresponding directory or `nil` for an empty folder; **name** is the localized
display name of the directory or "Files" for the root folder; **children** is
the list of folders and tracks that belong to the folder.

An **empty folder** is a folder with a path value of `nil`, a name value of
"Files" and an empty children list.


## Track

A **track** is a leaf node of the music library that corresponds to a music
file. A track exposes these properties:

    - **track name** is the localized display name of the music file with the
      extension removed
    - **album name** is the localized display name of the parent folder or "(no
      album)" if the track is a child of the root folder
    - **artist name** is the localized display name of the grandparent folder or
      "(no artist)" if the track is a child or grandchild of the root folder
    - **path** is the absolute path to the music file


## Track metadata

A **track metadata** holds the facts about a track's music file that are
gathered by reading the file. A track metadata has these properties:

    - **track** is the track the metadata describes
    - **size** is the music file size in bytes, as given by `stat.st_size` or
      equivalent library call
    - **file hash** is the XXH3 64-bit hash of the contents of the music file,
      or zero if the hash could not be calculated


## Queue

The **queue** is an in-memory list of tracks to play. The queue has one
property: **tracks** is the list of tracks in the queue, in play order. The same
track may appear in the queue more than once. The queue is owned by the player.

The queue is an **empty queue** when the tracks list is empty.

When given the **add track** command, the queue shall append the given track to
its tracks.

When given the **add folder** command, the queue shall append the track
descendants of the given folder to its tracks in preorder.

When given the **clear** command, the queue shall remove all tracks from its
tracks.


## Player

The **player** is the coordinator of track playback. The player owns the queue.

A **time index** is a non-negative number of seconds, including fractional
seconds, measured from the start of the current track. A time index beyond the
end of the current track is invalid and is clamped to the end of the track.

The player shall have an **audio** property that is the audio wrapper.

The player shall have a **queue** property that is its queue.

The player shall have a **current track** read-only calculated property that
returns the first track in the queue, or `nil` when the queue is empty.

The player shall have a **next track** read-only calculated property that
returns the second track in the queue, or `nil` when the queue contains fewer
than two tracks; the next track is passed to the audio wrapper to support
gapless playback.

The player shall have a **time index** property that is the time index for the
current track, or zero when the current track is `nil`.

The player shall have an **is playing** read-only boolean property that returns
true when the player is in the playback state and false when in the stopped
state. The "is playing" property may be implemented as a variable or as a
calculated property read from the audio wrapper.

**Playback** is the player state where audio is being played.

**Stopped** is the player state where no audio is being played. The player does
not have a separate "paused" state: the current track and time index properties
control where playback starts or resumes.


### Playback

While in playback and while there is a next track, when it finishes playing the
current track, the audio wrapper shall begin playing the next track without a
gap.

While in playback and while there is no next track, when it finishes playing the
current track, the audio wrapper shall stop playback.

While in playback, when the audio wrapper finishes playing the current track,
the player shall remove it from the queue.

While in playback, the player shall keep the time index in sync with the audio
wrapper by callback, notification or polling.


### Play command

While in playback, if given the **play** command, the player shall ignore the
command.

While stopped and while there is a current track, when given the play command,
the player shall start playing the current track at the time index and enter the
playback state.


### Stop command

While stopped, if given the **stop** command, the player shall ignore the
command.

While in playback, when given the stop command, the player shall update the time
index to the current playback position, stop audio playback and enter the
stopped state.


### Back command

While the queue is not empty, when given the back command, the player shall set
the time index to zero.

While in playback, when given the back command, the player shall begin playing
the current track from the start.


### Next command

While the queue is not empty, when given the next command, the player shall set
the time index to zero and discard the current track.

While in playback and while there is a next track, when given the next command,
the player shall stop playing the current track and begin playing the next track
from the start.

While in playback and while there is no next track, when given the next command,
the player shall stop playing the current track and enter the stopped state.


### Clear command

While the queue is not empty, when given the clear command, the player shall set
the time index to zero and clear the queue.

While in playback, when given the clear command, the player shall stop playback
and enter the stopped state.


### Command availability

While the queue is empty, the player shall ignore the play, stop, back, next and
clear commands.


# Snapshots

The snapshot library shall export three functions: get snapshot directory,
take snapshot and remove snapshot.

The snapshot library functions shall take a file system wrapper object as a
parameter.

The **get snapshot directory** function shall return a path inside the app's
application support director where the snapshot can reside.

If lookup of the application support directory fails, the get snapshot directory
function shall return `nil`.

The **take snapshot** function shall remove any previous snapshot and take a new
snapshot of the music root directory.

If it cannot create the snapshot, the take snapshot function shall return an
error.

The **remove snapshot** function shall remove the snapshot.

If it cannot remove the snapshot, the remove snapshot function shall return an
error.


# Launch behavior

The **music library store** is the object owned by the app that holds the app
music library and the errors from the most recent load. The music library store
has these properties: **library** is the app music library, initially an empty
music library; **load errors** is the list of errors from the most recent load,
initially empty; **load did fail** is a read-only calculated property that is
true when load errors is not empty.

When the app launches, MC Mus shall create a music library store and share it
with other views.

When the app launches, MC Mus shall create a player with an empty queue and
share the player with other views.

When the app launches and the `--demo` command line option is given, MC Mus is
in **demo mode** and shall wrap the file system wrapper in the demo file system
wrapper, created from the `demo-data.json` file in the app bundle, and the audio
wrapper in the demo audio wrapper, created with the URL of the `demo-track.mp3`
file in the app bundle, before creating the music library store and the player.

When the app launches, MC Mus shall locate the music root directory and call the
load music library function in the background, passing it the path of the music
root directory.

If locating the music root directory fails, MC Mus shall treat the failure as a
load result containing an empty music library and the error.

File sharing is not available in demo mode, since the demo root directory does
not exist on the local file system.

When a background load completes, MC Mus shall apply its load result to the
music library store on the main thread, replacing the library and the load
errors.


# User interface

MC Mus shall use "MC Mus" wherever the app name is displayed: window title, app
icon, menus, etc.

On macOS, MC Mus shall show a main window on launch.

The **main window content area** is the part of the main window below the title
bar; it excludes the title bar and any window border. Main window widths and
heights in this document are content area dimensions.

On macOS, MC Mus shall give the main window content area a width of 900 and a
height of 600 the first time the app launches.

On macOS, MC Mus shall give the main window content area a minimum width of 640
and a minimum height of 480.

On macOS, MC Mus shall retain the previous main window width and height between
subsequent launches.

On macOS, MC Mus shall show two equally-sized panels in the main window: the
files panel on the left side and the queue panel on the right side.

On macOS, MC Mus shall only allow one main window without tabs, and shall quit
the app when the main window is closed.

On iOS, MC Mus shall show a main view on launch.

On iOS, while the screen is in right-side-up portrait orientation, MC Mus shall
show two equally-sized panels in the main view: the files panel shall be on the
top and the queue panel on the bottom.

On iOS, where the device supports upside-down portrait orientation, while the
screen is in upside-down portrait orientation, MC Mus shall show two
equally-sized panels in the main view: the files panel shall be on the top and
the queue panel on the bottom.

On iOS, while the screen is in landscape orientation, MC Mus shall show two
equally-sized panels in the main view: the files panel shall be on the left side
and the queue panel on the right side.

A **panel title area** is the area at the top of a panel that holds the title
text and optionally other controls.

On iOS, MC Mus shall draw panel titles on an opaque secondary system background.


## Files panel

The **find button** is a button with the label "Find".

The **empty files view** is a view that shows the title "No music", description
"The music library is empty." and a folder system icon all centered in the view.

On macOS, the files panel shall show the title "Files" and the find button with
bordered style at the top of the panel.

On macOS, while the music library is empty, the files panel shall disable the
find button.

On macOS, while the music library is not empty, the files panel shall enable the
find button.

On iOS, while the music library is empty, the files panel shall show the title
"Files" and the find button with bordered style at the top of the panel, and
shall disable the find button. Note that this find button only serves as a
placeholder and is always disabled; on iOS the files table stack contains the
active find button.

On iOS, while the music library is not empty, the files panel shall hide the
title "Files" and the find button at the top of the panel.

The files panel shall get the music library and load did fail state from the
app's music library store.

While the music library is empty, the files panel shall show the empty files
view.

On macOS, while the music library is empty, the files panel shall show the empty
files view filling the space above the share status bar.

While the music library is not empty, the files panel shall hide the empty files
view.

While the music library is empty and load did fail is true, the files panel
shall set the description of the empty files view to "The music library did not
load.".


### Files tree

The **files tree** is a tree view that displays a music library on macOS.

A **folder item** is an item in the files tree that contains a folder and shows
the folder name. A folder item can be expanded to show its children or collapsed
to hide them.

A **track item** is an item in the files tree that contains a track and shows
the track name.

On macOS, while the music library is empty, the files panel shall hide the files
tree.

On macOS, while the music library is not empty, the files panel shall show the
files tree backed by the music library, filling the space above the share status
bar.

On macOS, when the user drags a folder item, the files tree shall start a drag
carrying the folder of the item.

On macOS, when the user drags a track item, the files tree shall start a drag
carrying the track of the item.


### Files table stack

The **files table stack** is a navigation stack that displays the music library
on iOS.

A **folder table** is a table view that shows one row for each folder or track
child of the corresponding folder, sets the title to the name of the folder and
adds a find button in bordered style to the right side of the navigation bar.

A folder table shall draw itself in the standard "plain" style.

A **folder row** is a folder table row that shows the name of the corresponding
folder and contains a "[+]" button (SF Symbol `plus.square`) and a ">" button
(standard disclosure chevron) on the right side of the row.

When the user taps the "[+]" button on a folder row, MC Mus shall add that
folder to the queue.

When the user taps the ">" button on a folder row, MC Mus shall push a new
folder table backed by that folder onto the files table stack.

A **track row** is a folder table row that shows the track name of the
corresponding track and contains a "(+)" (SF Symbol `plus.circle`) button on the
right side of the row.

On iOS, when the user taps the "(+)" button on a track row, MC Mus shall add
that track to the queue.

On iOS, while the music library is empty, the files panel shall hide the files
table stack.

On iOS, while the music library is not empty, the files panel shall show a files
table stack backed by the music library.

On iOS, the folder table shall draw the navigation bar with the same opaque
background as a panel title, regardless of the folder table's scroll position.

On iOS, when the user taps a folder row, the files table stack shall push a new
folder table onto the navigation stack backed by the folder of the tapped row.


### Share status bar

The **share status bar** is a view that displays file sharing control and state
on macOS.

The **share switch** is a toggle switch control that enables and disables file
sharing on macOS.

The **share status label** shows the current status of file sharing on macOS.

The share status bar shall show the label "File Sharing" on the left side and
the share switch on the right side of the bar.

The share status bar shall show the share status label in the available space
between the "File Sharing" label and the share switch; the share status label
shall use a smaller font and lighter color than the "File Sharing" label.

The share switch shall be off by default.

On macOS, while the music library is empty and file sharing is off, the share
switch shall be disabled.

On macOS, the files panel shall show the share status bar at the bottom of the
files panel, whether or not the music library is empty.

On macOS, while file sharing is off, the share status label shall show the
text "Not sharing."

On macOS, while file sharing is on, the share status label shall show the text
"No device connected."

On macOS, when the share switch is switched on, MC Mus shall create a snapshot
of the music library and log the time needed to create the snapshot.

On macOS, if creating a snapshot fails, MC Mus shall set the share switch state
to off and report the error in the share status label.

On macOS, when the share switch is switched off, MC Mus shall remove the
snapshot of the music library.

On macOS, MC Mus shall create and remove snapshots off the main thread so that
the UI stays responsive.

On macOS, while a snapshot is being created or removed, the share switch shall
be disabled and ignore input.

On macOS, if creating or removing a snapshot takes longer than a short delay,
the share status label shall show the text "Creating snapshot…" or "Removing
snapshot…" and an indeterminate progress indicator shall appear between the
share status label and the share switch; once shown, they shall remain visible
for a minimum duration so that they do not flicker.


## Queue panel

The **clear button** is a button with the label "Clear".

The **empty queue view** is a view that shows title "No tracks", description
"The queue is empty." and a "bullet list" system icon all centered in the view.

The queue panel shall show the title "Queue" and the clear button at the top of
the panel. The title shall be centered; the title and clear button shall be
vertically aligned; the clear button shall be horizontally positioned on the
right side of the panel.

The queue panel shall get its tracks from the player's queue.

The queue panel shall show the player panel at the top of the queue panel.

While the queue is empty, the queue panel shall show the empty queue view, hide
the queue table and disable the clear button.

While the queue is not empty, the queue panel shall hide the empty queue view,
show the queue table and enable the clear button.

On macOS, when a track item from the files tree is dropped on the queue panel,
the queue panel shall give the queue the add track command with the track of the
item.

On macOS, when a folder item from the files tree is dropped on the queue panel,
the queue panel shall give the queue the add folder command with the folder of
the item.

When the user clicks or taps it, the clear button shall send the clear command
to the player.


### Player panel

The **player panel** is a view containing playback controls: back, play/stop and
next buttons.

The **play/stop button** is a button that shows a play triangle (SF Symbol
`play.fill`) while the player is stopped and shows a stop square (SF Symbol
`stop.fill`) while the player is in playback.

The **back button** is a button that shows the backward double triangle (SF
Symbol `backward.fill`).

The **next button** is a button that shows the forward double triangle (SF
Symbol `forward.fill`).

The player panel shall show the play/stop button in the center of the panel,
with the back button aligned to the left side of the play/stop button and the
next button aligned to the right side of the play/stop button. The ASCII
schematic below shows the arrangement of buttons in the view.

    +--------------------------------------------------+
    |             [ << ]  [  >  ]  [ >> ]              |
    +--------------------------------------------------+

The back button and next button shall have the same width.

The play/stop button shall be 20% wider than the back button and next button.

The player panel shall have a fixed height tall enough to show its contents with
standard padding and a width that fills the width of the queue panel.

When the queue is empty, the player panel shall disable the back button,
play/stop button and next button.

When the queue is not empty, the player panel shall enable the back button,
play/stop button and next button.

While the player is in playback, when the user clicks or taps it, the play/stop
button shall send the stop command to the player.

While the player is stopped, when the user clicks or taps it, the play/stop
button shall send the play command to the player.

When the user clicks or taps it, the back button shall send the back command to
the player.

When the user clicks or taps it, the next button shall send the next command to
the player.


### Queue table

The **queue table** is a table view with one queued track row for each track in
the queue, in queue order.

A **queued track row** is a table view row in the queue table.

The queue table shall fill all available space in the queue panel below the
player panel.

The queue table shall show a queued track row for each track in the queue, in
the same order as the queue.

The queue table shall draw itself in the standard "plain" style.

When new tracks are added to the queue, MC Mus shall scroll the queue table to
the end so that the last of the newly added queued track rows are visible.


#### Queued track row

A queued track row shall show the track name, album name and artist name in the
same table cell.

A queued track row shall contain two text lines: upper and lower.

The upper text line of a queued track row shall show the track name.

The lower text line of a queued track row shall show the album name and artist
name in smaller, dimmer text, with the album name on the left and left-justified
and the artist name on the right and right-justified.

The ASCII schematic below shows the arrangement of text in the queued track row.

    +--------------------------------------------------+
    | <track name .................................. > |
    | <album name .............. > < .... artist name> |
    +--------------------------------------------------+
    ^                             ^                    ^
    +------------- 60% -----------+-------- 40% -------+

While the album name and artist name both fit on the lower text line of a queued
track row, each shall occupy the width it needs.

While the album name and artist name do not both fit on the lower text line,
the album name shall occupy up to 60% of the lower text line, inclusive of
padding, and the artist name shall occupy up to 40%.

While the track name, album name or artist name does not fit in the available
space, the queued track row shall use elision to truncate the text.


## Menus

### Standard menus

On macOS, MC Mus shall have a menu bar with these menus, in order: the app
("MC Mus") menu, "File", "Edit" and "Window".

On macOS, the app menu shall contain these items, in order: "About MC Mus",
"Settings…" (⌘,), "Services", "Hide MC Mus" (⌘H), "Hide Others" (⌥⌘H), "Show
All" and "Quit MC Mus" (⌘Q).

On macOS, the "File" menu shall contain the item "Close" (⌘W).

On macOS, the "Edit" menu shall contain these items, in order: "Undo" (⌘Z),
"Redo" (⇧⌘Z), "Cut" (⌘X), "Copy" (⌘C), "Paste" (⌘V), "Delete" and "Select
All" (⌘A).

On macOS, the "Window" menu shall contain these items, in order: "Minimize"
(⌘M), "Zoom" and "Bring All to Front".


### Settings menu

On macOS, MC Mus shall have a "Settings…" menu item under the app ("MC Mus")
menu.

On macOS, when the "Settings…" menu item is selected, MC Mus shall present the
setting dialog.


## Settings dialog

The settings dialog shall display one setting: **Music files**.

The music files setting shall consist of the **music files text box**, the label
"Music Files:", a read-only text box that displays the current value of the
music root directory, and the **choose music files button**, a button with label
"Choose…".

The music files text box shall not accept keyboard focus; the tab order of the
settings dialog shall skip it.

The music files text box shall allow the user to select and copy its text but
shall not allow the user to edit it.

When a user clicks the choose music files button, the settings dialog shall open
the system file chooser, initialized to the current path in the music files text
box, and configured to allow the user to choose a directory and with allowed
content types set to `.mp3` and `.m4a` files so that other file types are
dimmed.

When the user chooses a directory in the file chooser, the settings dialog shall
update the music files text box.

When the user chooses a different music root directory in the settings dialog,
MC Mus shall stop accessing the previous music root directory if it was security
scoped, save the new music root directory to user defaults as a security-scoped
bookmark, start accessing it, load the new music library in the background and
update the app when the new music library has loaded.
