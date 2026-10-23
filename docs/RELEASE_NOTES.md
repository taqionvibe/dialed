## Dialed 1.0.1

**Install:** download **`Dialed.dmg`**, open it and drag **Dialed** to Applications (or use `Dialed.zip`). The first time, right-click Dialed → **Open** (the app isn't notarized). The setup window covers the Nothing X dial settings and the Accessibility permission.

### What's new
- **DMG installer** with a drag-to-Applications window and first-launch hint.
- **"Made with ♥ by Taqi Saeed"** credit, linking to [taqisaeed.com](https://taqisaeed.com), in the About page, menu bar panel and welcome screen.
- Redesigned README.

### Tested with real CMF Buds Pro 2 (macOS 27)
Turns, single / double / triple presses, the radial menu, all 11 built-in modes, macros and Apple Shortcuts, play-pause and next track for YouTube Music while it plays, case in/out, sleep/wake and the off switch. Full report: `docs/HARDWARE-TESTING.md`.

### Known limitations
- Press-and-hold never reaches macOS.
- macOS shows its own volume indicator on each click (no public API hides it).
- Dialed appears under Now Playing while it's on (macOS only sends the buds' presses to that app).
- Unsigned build: macOS asks for Accessibility again after updating.

Made with ❤️ by [Taqi Saeed](https://taqisaeed.com)
