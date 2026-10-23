# Dialed promo reels

Instagram reels (1080×1920, 30 fps) made with [Remotion](https://www.remotion.dev): motion graphics that recreate
Dialed's real UI — a CMF-style dial, the radial menu, the HUD — with synthesized sound effects.

| Composition | Length | What it shows |
|---|---|---|
| `Hero-en` / `Hero-ur` | 21 s | Hook → logo → radial menu → five-mode montage → features → call to action |
| `Radial-en` / `Radial-ur` | 10.5 s | Triple-press → turn to pick → press to choose → the dial scrolls |
| `Profiles-en` / `Profiles-ur` | 10.5 s | Keynote → Slides, Safari → Scroll, QuickTime → Video Seek |

```bash
npm install
npm run studio          # live preview and editing
npm run render:all      # renders all six MP4s into out/
```

- Text for both languages lives in `src/copy.ts`; timing and scenes in `src/reels.tsx`.
- `scripts/symbols.swift` renders the SF Symbols used for icons, `scripts/sfx.py` synthesizes the sound
  effects (no third-party audio), `scripts/sheet.sh` makes a contact sheet of frames for review.
- On-screen text stays inside Instagram's safe area (`SAFE` in `src/theme.ts`).
