## Dialed 1.0

Turn the Smart Dial on the CMF Buds Pro 2 case into a Mac controller.

**Install:** download **`Dialed.dmg`**, open it and drag **Dialed** to Applications (or use `Dialed.zip`), then right-click → **Open** the first time (the app isn't notarized). Follow the setup window; it covers the Nothing X dial settings and the Accessibility permission.

### Highlights
- 11 built-in modes: Volume, Scroll (smooth, with fast-spin boost), Media, Video Seek, Brightness, Zoom, Browser Tabs, Slides, App Switcher, Windows, Undo / Redo
- Radial menu (triple press) with click-to-choose, click-away and Esc
- Per-app profiles with automatic switching, editable radial items, remappable presses
- Custom modes, macros, Apple Shortcuts, keyboard shortcuts, open apps/links, type text
- On-screen feedback, live diagnostics, settings import/export
- Handles sleep/wake, buds going into the case, reconnects, accidental turns and fast spins
- Turning Dialed off gives the buds back to macOS completely

### Tested on real hardware
macOS 27.0.1 with CMF Buds Pro 2: turns, single/double/triple presses, volume restore, radial menu, Volume/Scroll/Media modes, play/pause and next track forwarded to YouTube Music, keeping the presses while music plays, case in/out and sleep/wake. Full report: `docs/HARDWARE-TESTING.md`.

### Known limitations
- Press-and-hold never reaches macOS.
- macOS shows its own volume indicator on each click (no public API hides it).
- Dialed appears under Now Playing while it's on (macOS only sends the buds' presses to that app).
- Unsigned build: macOS asks for Accessibility again after updating.
