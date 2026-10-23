# Dialed promo reels

Instagram reels (1080×1920, 30 fps) made with [Remotion](https://www.remotion.dev), aimed at people who already own
CMF Buds Pro 2: each one opens by asking whether they only use the case dial for music, then shows what Dialed does.
The case is the real one (cut out from photos of a white CMF Buds Pro 2 case); its actual dial disc rotates on every click.
Cuts land on the beat of the music track, with synthesized sound effects on top.

| Composition | Length | What it shows |
|---|---|---|
| `Hero-en` / `Hero-ur` | 25.7 s | Owner hook → drop + logo → five-mode montage → radial menu → features → end card |
| `Radial-en` / `Radial-ur` | 12.4 s | Owner hook → triple-press → turn to pick → press to choose → the dial scrolls |
| `Profiles-en` / `Profiles-ur` | 12.4 s | Owner hook → Keynote → Slides, Safari → Scroll, QuickTime → Video Seek |

```bash
npm install
npm run studio          # live preview and editing
npm run render:all      # renders all six MP4s into out/
```

- Text for both languages lives in `src/copy2.ts`; scenes and beat timing in `src/reels2.tsx`; reusable motion
  pieces (real case, camera punch, slam text, whip, MacBook) in `src/motion.tsx`.
- `scripts/cutout.swift` lifts the case out of a photo (Vision), `scripts/finddial.swift` crops the dial disc.
- `scripts/symbols.swift` renders the SF Symbols used for icons, `scripts/sfx.py` synthesizes the sound
  effects, `scripts/sheet.sh` makes a contact sheet of frames for review.
- On-screen text stays inside Instagram's safe area (`SAFE` in `src/theme.ts`).

## Music

"Uplifting Bass" by Lily J, from [Mixkit](https://mixkit.co/free-stock-music/), under the
[Mixkit Stock Music Free License](https://mixkit.co/license/#musicFree), which allows its use in social media videos.
The drop (14.38 s into the track) is lined up with the reel's big reveal. The license doesn't allow sharing the
audio file on its own, so it isn't in the repo: download the track from Mixkit and save it as
`public/music/uplifting-bass.mp3` before rendering.
