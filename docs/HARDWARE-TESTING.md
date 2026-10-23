# Hardware test report

**Setup:** MacBook Pro (Apple Silicon), macOS 27.0.1 (26A434), CMF Buds Pro 2 connected over
Bluetooth (A2DP + AVRCP + HFP), Nothing X dial settings: Single = Play/Pause, Double = Next track,
Triple = Previous track. Tests were run on 23 Oct 2026 with the buds in the tester's ears.

Two kinds of evidence are used:

- **Probe**: a throwaway app that logged every CoreAudio volume change and every
  `MPRemoteCommand`, alongside `bluetoothd`'s own log (`com.apple.bluetooth:Server.Remote`).
- **Dialed**: the app's Diagnostics log while the tester used it, plus their confirmation of what
  happened on screen.

## How the dial reaches macOS (verified)

| Gesture | What arrives on the Mac | Result |
|---|---|---|
| Turn | AVRCP absolute-volume notification → CoreAudio volume of the buds' output device. One report = one step of a 16-step grid (raw AVRCP 0, 8, 16 … 64, 71, 79 … 127). | ✅ Verified |
| Turn, fast spin | Reports arrive no faster than ~one per 0.3–0.6 s; the buds drop the clicks in between (6 fast clicks → 2–6 reports). | ✅ Verified, compensated by the fast-spin boost |
| Turn, Mac not playing audio | Not observed while another device (phone, dual connection) was the active source. With Dialed's silent stream every turn arrived. | ✅ Verified (reason for the silent stream) |
| Single press | AVRCP Play or Pause (the buds alternate) → `playCommand` / `pauseCommand` | ✅ Verified |
| Double press | AVRCP Next Track → `nextTrackCommand` | ✅ Verified |
| Triple press | AVRCP Previous Track → `previousTrackCommand`, **only** when Nothing X sets Triple to "Previous track". Set to "Low lag mode" or "No action", nothing reaches the Mac (bluetoothd logs nothing). | ✅ Verified |
| Press and hold | Nothing. `bluetoothd` logs no AVRCP or HFP event; no CoreAudio side effect. | ❌ **Unsupported on macOS** |
| Restoring the volume | Writing the level back after each click is accepted every time (20/20 clicks), takes effect in ~30 ms, and the next click is reported relative to the restored level. | ✅ Verified |
| Reconnect | The buds get a new CoreAudio device ID every time they reconnect. | ✅ Verified, handled |

## Dialed features tested with the buds

| Feature | Result |
|---|---|
| Volume mode: turning changes volume, HUD shows the level | ✅ |
| Radial menu: triple press opens it, turning moves the highlight, single press chooses | ✅ |
| Radial menu: click outside / Esc closes, clicking an item chooses it | ✅ |
| Scroll mode in Chrome, volume stays at the listening level | ✅ |
| Fast spins scroll much further (after tuning from the logs) | ✅ |
| Media mode: next / previous track | ✅ |
| Single press → play/pause forwarded to YouTube Music (non-scriptable player) | ✅ |
| Double press → next song in YouTube Music | ✅ |
| Presses keep reaching Dialed **while YouTube Music is playing** (re-claim) | ✅ (after three iterations — see below) |
| Buds into the case → Dialed releases media controls and leaves Now Playing; out of the case → reconnects on its own | ✅ |
| Sleep / wake → input paused, buds re-attached, presses work after wake | ✅ (from the log of a real sleep/wake cycle) |
| Brightness, Zoom (Chrome), Browser Tabs (Chrome): on-screen effect confirmed by the tester | ✅ |
| Undo / Redo, Video Seek: chosen from the radial menu and turned | ✅ mode switch and clicks verified in the log; on-screen effect not separately confirmed |
| Turning Dialed **off**: buds change volume and control music normally; turning it back on | ✅ |
| Menu bar panel: on, off and setup states keep a stable size (macOS 27 MenuBarExtra fix) | ✅ |
| Accessibility permission flow, menu bar status | ✅ |

### What changed because of hardware testing

- **Silent stream** to keep the Mac the buds' active device (turns didn't arrive without it).
- **Fast-spin boost** retuned to the measured report spacing (0.55–1.0 s) and raised to 5×.
- **Media forwarding**: lowering Dialed's playback state wasn't enough — the key came back to
  Dialed. Dialed now steps aside completely for a moment, sends the key, then takes the presses back.
- **Keeping presses while music plays**: macOS gives the buds' presses to whichever app most
  recently started or changed playback. A one-time re-claim lost to YouTube Music on the next track
  change, so Dialed watches CoreAudio process activity and re-claims every 2 s while another app is
  playing.
- **Default presses**: single = mode action, double = next track, triple = radial menu
  (tester's preference).
- Ignores volume ramps macOS performs while switching output devices (they were read as clicks).

## Not tested on hardware

These are built and unit-tested where possible, but were not exercised with the buds:
App Switcher, Windows, Slides (Keynote/PowerPoint), custom modes, macros, Apple Shortcuts actions,
automatic profile switching, Spotify/Music AppleScript forwarding, Launch at Login, settings
import/export in the UI (the format is unit-tested), external displays for Brightness.

## Known macOS limitations

- **Press and hold** never reaches macOS.
- **macOS volume popup**: every dial click is a volume change, so macOS shows its own volume
  indicator. No public API hides it.
- **Now Playing**: macOS sends the buds' presses only to the app listed under Now Playing, so
  Dialed appears there while it is on and the buds are connected (it leaves when Dialed is off or
  the buds are in the case). While another app plays, Control Center may show Dialed instead of the song.
- **Per-click volume blip**: in non-volume modes the buds change volume for ~30 ms before Dialed
  restores it; you may hear a tiny blip, and the buds play their own tick.
- **Dropped clicks** on very fast spins happen inside the buds and can't be recovered.
- **Unsigned builds**: without a Developer ID, macOS asks for Accessibility again after each update.
