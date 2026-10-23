import React from 'react';
import {AbsoluteFill, Audio, interpolate, Sequence, spring, staticFile, useCurrentFrame} from 'remotion';
import {AppIcon, Background, Chip, HUD, RadialMenu} from './components';
import {Lang} from './copy';
import {copy2} from './copy2';
import {ScreenKind} from './MacScreen';
import {beatGrid, Camera, Eyebrow, Flash, MacBook, RealCaseSide, RealCaseTop, Ring, Slam, Whip} from './motion';
import {C, font, SAFE} from './theme';

// Music: "Uplifting Bass" by Lily J (Mixkit Stock Music Free License).
// The drop is at 14.38 s in the track; kicks then land every ~0.923 s.
const DROP_IN_TRACK = 14.38;
const BEAT = 27.7; // frames per kick at 30 fps
const HALF = BEAT / 2;

/** Spring that starts at frame `at` (plain function, safe inside conditionals). */
const sp = (f: number, at: number, damping = 14) => spring({frame: f - at, fps: 30, config: {damping}});

const Music: React.FC<{dropAt: number; total: number}> = ({dropAt, total}) => {
  const startFrom = Math.round((DROP_IN_TRACK * 30) - dropAt);
  return (
    <Audio
      src={staticFile('music/uplifting-bass.mp3')}
      startFrom={startFrom}
      volume={(f) => interpolate(f, [0, 8, total - 40, total - 2], [0, 0.85, 0.85, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}
    />
  );
};

const Sfx: React.FC<{at: number; name: 'click' | 'tick' | 'whoosh' | 'pop' | 'boom'; volume?: number}> = ({at, name, volume = 0.5}) => (
  <Sequence from={Math.round(at)} durationInFrames={30} layout="none">
    <Audio src={staticFile(`sfx/${name}.wav`)} volume={volume} />
  </Sequence>
);

const Top: React.FC<{children: React.ReactNode; y?: number}> = ({children, y = SAFE.top + 20}) => (
  <div style={{position: 'absolute', left: SAFE.side, right: SAFE.side, top: y, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 26}}>{children}</div>
);
const Center: React.FC<{children: React.ReactNode; y?: number}> = ({children, y = 0}) => (
  <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', transform: `translateY(${y}px)`}}>{children}</AbsoluteFill>
);
const show = (f: number, a: number, b: number) => f >= a && f < b;
const fade = (f: number, a: number, b: number) =>
  Math.min(interpolate(f, [a, a + 6], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}), interpolate(f, [b - 6, b], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}));

/** Smooth count of clicks so far (each click eases in over ~6 frames). */
const clicksSoFar = (f: number, ats: number[]) =>
  ats.reduce((s, a) => s + interpolate(f, [a, a + 6], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}), 0);

const RADIAL = [
  {symbol: 'speaker.wave.2.fill', label: 'Volume', hint: 'Turn'},
  {symbol: 'arrow.up.and.down', label: 'Scroll', hint: 'Turn'},
  {symbol: 'music.note', label: 'Media'},
  {symbol: 'film', label: 'Video Seek'},
  {symbol: 'sun.max.fill', label: 'Brightness'},
  {symbol: 'plus.magnifyingglass', label: 'Zoom'},
  {symbol: 'square.on.square', label: 'Browser Tabs'},
  {symbol: 'square.grid.2x2.fill', label: 'App Switcher'},
  {symbol: 'arrow.uturn.backward', label: 'Undo / Redo'},
];

/** Closing card used by every reel. */
const End: React.FC<{lang: Lang; at: number; beats: number[]}> = ({lang, at, beats}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const icon = sp(f, at, 10);
  const name = sp(f, at + 6);
  const cta = sp(f, at + 14);
  const made = sp(f, at + 24);
  return (
    <AbsoluteFill>
      <Camera beats={beats} push={0.04} from={at}>
        <Background glowY={0.42} intensity={1.3} />
        <Top y={SAFE.top - 10}>
          <Eyebrow text={t.only} at={at + 2} />
        </Top>
        <Center y={-40}>
          <AppIcon size={290} style={{transform: `scale(${0.4 + 0.6 * icon}) rotate(${(1 - icon) * -90}deg)`, opacity: icon}} />
          <div style={{fontFamily: font, fontWeight: 900, fontSize: 160, color: 'white', letterSpacing: -7, marginTop: 14, opacity: name, transform: `translateY(${(1 - name) * 50}px)`}}>
            Dialed
          </div>
          <div style={{marginTop: 24, opacity: cta, transform: `scale(${0.8 + 0.2 * cta})`}}>
            <Chip label={t.cta} appear={1} hot size={50} />
          </div>
          <div style={{fontFamily: font, fontSize: 34, fontWeight: 600, color: C.dim, marginTop: 24, opacity: cta}}>
            {t.ctaSub} · github.com/taqionvibe/dialed
          </div>
        </Center>
        <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom + 10, textAlign: 'center', fontFamily: font, fontSize: 32, fontWeight: 600, color: C.faint, opacity: made}}>
          Made with <span style={{color: C.accent}}>♥</span> by <span style={{color: 'white'}}>Taqi Saeed</span>
        </div>
      </Camera>
    </AbsoluteFill>
  );
};

// ═══════════════════════════ HERO v2 (~25 s) ═══════════════════════════

const DROP = 210;
const MONTAGE_AT = 328;
const SEG = Math.round(BEAT * 1.5); // 42
const KINDS: {kind: ScreenKind; symbol: string; hud: string; level?: boolean}[] = [
  {kind: 'scroll', symbol: 'arrow.up.and.down', hud: 'Scroll'},
  {kind: 'slides', symbol: 'play.rectangle.fill', hud: 'Slides'},
  {kind: 'video', symbol: 'film', hud: 'Video Seek'},
  {kind: 'brightness', symbol: 'sun.max.fill', hud: 'Brightness', level: true},
  {kind: 'volume', symbol: 'speaker.wave.2.fill', hud: 'Volume', level: true},
];
export const HERO2_LEN = 770;

export const Hero2: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const beats = beatGrid(DROP, 21, BEAT);
  const RADIAL_AT = MONTAGE_AT + KINDS.length * SEG; // 538
  const FEAT_AT = RADIAL_AT + Math.round(BEAT * 2.5); // 607
  const END_AT = FEAT_AT + Math.round(BEAT * 2.2); // 668

  // Intro dial clicks (quiet part), then a fast build-up spin.
  const introClicks = [94, 108, 122];
  const buildSpin = interpolate(f, [176, DROP], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const introRot = clicksSoFar(f, introClicks) * 24 + Math.pow(buildSpin, 2.2) * 540;

  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Music dropAt={DROP} total={HERO2_LEN} />

      {/* ── Intro (before the drop) ── */}
      {f < DROP ? (
        <Camera push={0.08} shake={buildSpin * 6}>
          <Background glowY={0.6} intensity={0.6 + buildSpin} />
          <Top>
            <Eyebrow text={t.eyebrow} at={4} out={DROP - 6} />
            {show(f, 8, 72) ? <Slam text={t.own1} at={10} size={104} hot={['CMF', 'Buds', 'Pro', '2']} out={66} /> : null}
            {show(f, 70, 142) ? <Slam text={t.own2} at={72} size={88} hot={['volume', 'volume…', 'gaanon']} out={136} /> : null}
            {show(f, 140, 178) ? <Slam text={t.own3} at={142} size={104} out={172} /> : null}
            {show(f, 176, DROP) ? <Slam text={t.build} at={176} size={92} hot={['Mac', 'Mac?']} /> : null}
          </Top>
          {f < 72 ? (
            <Center y={240}>
              <div style={{opacity: fade(f, 0, 72), transform: `translateY(${interpolate(f, [0, 30], [80, 0], {extrapolateRight: 'clamp'})}px)`}}>
                <RealCaseSide width={860} tiltY={interpolate(f, [0, 72], [-22, 8])} tiltX={interpolate(f, [0, 72], [12, 4])} />
              </div>
            </Center>
          ) : (
            <Center y={260}>
              <div
                style={{
                  opacity: fade(f, 70, DROP + 2),
                  transform: `scale(${interpolate(f, [70, 100, 140, 178, DROP], [0.85, 1, 1, 0.92, 1.25], {extrapolateRight: 'clamp'})})`,
                  filter: show(f, 140, 178) ? `grayscale(${interpolate(f, [140, 156], [0, 0.85], {extrapolateRight: 'clamp'})})` : undefined,
                }}
              >
                <RealCaseTop width={700} rotation={introRot} clicks={introClicks} glow={0.4 + buildSpin * 1.6} />
              </div>
            </Center>
          )}
          {introClicks.map((a) => (
            <Sfx key={a} at={a} name="click" volume={0.55} />
          ))}
        </Camera>
      ) : null}

      {/* ── Drop: "It can now." + logo ── */}
      {show(f, DROP, 268) ? (
        <Camera beats={beats} push={0.06} from={DROP}>
          <Background glowY={0.45} intensity={1.6} />
          <Center y={-120}>
            <div style={{opacity: interpolate(f, [DROP + 22, DROP + 28], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}}>
              <Slam text={t.drop} at={DROP} size={150} color={C.accent} />
            </div>
          </Center>
          <Center y={-40}>
            <div style={{opacity: f >= DROP + 24 ? 1 : 0, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
              <LogoBlock at={DROP + 24} />
            </div>
          </Center>
          <div style={{position: 'absolute', left: 540, top: 880}}>
            <Ring at={DROP} x={0} y={0} size={500} length={22} width={14} />
            <Ring at={DROP + 4} x={0} y={0} size={300} length={22} width={8} color="white" />
          </div>
        </Camera>
      ) : null}
      <Flash at={DROP} length={12} />
      <Sfx at={DROP} name="boom" volume={0.7} />

      {/* ── Clarify: a free Mac app for your CMF dial ── */}
      {show(f, 268, MONTAGE_AT) ? (
        <Camera beats={beats} push={0.05} from={268}>
          <Background glowY={0.62} intensity={1.2} />
          <Top>
            <Slam text={t.clarify} at={270} size={88} hot={['free', 'CMF']} />
          </Top>
          <Center y={250}>
            <div style={{transform: `scale(${0.9 + 0.1 * sp(f, 270)})`}}>
              <RealCaseTop width={680} rotation={clicksSoFar(f, [284, 298, 312]) * 30} clicks={[284, 298, 312]} glow={1.3} />
            </div>
          </Center>
          {[284, 298, 312].map((a) => (
            <Sfx key={a} at={a} name="click" volume={0.4} />
          ))}
        </Camera>
      ) : null}

      {/* ── Montage: one mode per 1.5 beats, whip transitions ── */}
      {KINDS.map((m, i) => {
        const a = MONTAGE_AT + i * SEG;
        if (!show(f, a - 1, a + SEG + 1)) return null;
        const clicks = [a + 4, a + 4 + HALF, a + 4 + BEAT].map(Math.round);
        const steps = clicksSoFar(f, clicks);
        const level = m.kind === 'brightness' ? Math.max(0.15, 1 - steps * 0.25) : Math.min(1, 0.3 + steps * 0.2);
        return (
          <Whip key={i} inAt={a} outAt={a + SEG}>
            <Camera beats={beats} push={0.03} from={a}>
              <Background glowX={i % 2 ? 0.3 : 0.7} glowY={0.55} intensity={1.2} />
              <Top y={SAFE.top - 20}>
                <Slam text={t.montage[i]} at={a + 1} size={96} />
              </Top>
              <Center y={-90}>
                <div style={{position: 'relative'}}>
                  <MacBook kind={m.kind} steps={steps} />
                  <div style={{position: 'absolute', left: 0, right: 0, bottom: 90, display: 'flex', justifyContent: 'center'}}>
                    <HUD symbol={m.symbol} title={m.hud} level={m.level ? level : undefined} subtitle={m.level ? `${Math.round(level * 100)}%` : undefined} appear={sp(f, a + 4)} scale={2} />
                  </div>
                </div>
              </Center>
              <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom - 150, display: 'flex', justifyContent: 'center'}}>
                <RealCaseTop width={430} rotation={steps * 32 + i * 50} clicks={clicks} glow={1} />
              </div>
            </Camera>
          </Whip>
        );
      })}
      {KINDS.map((_, i) => {
        const a = MONTAGE_AT + i * SEG;
        return (
          <React.Fragment key={i}>
            <Sfx at={a} name="whoosh" volume={0.35} />
            {[a + 4, a + 4 + HALF, a + 4 + BEAT].map((c) => (
              <Sfx key={c} at={c} name="click" volume={0.45} />
            ))}
          </React.Fragment>
        );
      })}

      {/* ── Radial menu ── */}
      {show(f, RADIAL_AT, FEAT_AT) ? (
        <Whip inAt={RADIAL_AT} outAt={FEAT_AT}>
          <Camera beats={beats} push={0.04} from={RADIAL_AT}>
            <Background intensity={1.3} />
            <Top y={SAFE.top - 20}>
              <Slam text={t.radial} at={RADIAL_AT + 1} size={88} hot={['radial', 'Triple-press']} />
            </Top>
            <Center y={130}>
              <RadialMenu
                items={RADIAL}
                highlight={clicksSoFar(f, [RADIAL_AT + 18, RADIAL_AT + 32, RADIAL_AT + 46])}
                appear={sp(f, RADIAL_AT + 4, 12)}
                size={880}
              />
            </Center>
          </Camera>
        </Whip>
      ) : null}
      <Sfx at={RADIAL_AT} name="whoosh" volume={0.35} />
      {[RADIAL_AT + 4, RADIAL_AT + 8, RADIAL_AT + 12].map((a) => (
        <Sfx key={a} at={a} name="pop" volume={0.35} />
      ))}
      {[RADIAL_AT + 18, RADIAL_AT + 32, RADIAL_AT + 46].map((a) => (
        <Sfx key={a} at={a} name="tick" volume={0.5} />
      ))}

      {/* ── Features ── */}
      {show(f, FEAT_AT, END_AT) ? (
        <Camera beats={beats} push={0.05} from={FEAT_AT}>
          <Background glowY={0.5} intensity={1.3} />
          <Center>
            <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 30}}>
              {t.features.map((label, i) => {
                const at = FEAT_AT + Math.round(i * HALF);
                return (
                  <div key={label} style={{transform: `scale(${1.5 - 0.5 * sp(f, at, 11)})`, opacity: sp(f, at, 11)}}>
                    <Chip symbol={['dial.medium.fill', 'person.crop.rectangle.stack', 'wand.and.stars', 'arrow.clockwise'][i]} label={label} hot={i === 0} size={56} appear={1} />
                  </div>
                );
              })}
            </div>
          </Center>
        </Camera>
      ) : null}
      {[0, 1, 2, 3].map((i) => (
        <Sfx key={i} at={FEAT_AT + i * HALF} name="pop" volume={0.35} />
      ))}

      {/* ── End ── */}
      {f >= END_AT ? <End lang={lang} at={END_AT} beats={beats} /> : null}
      <Flash at={END_AT} length={8} color={C.accent} />
    </AbsoluteFill>
  );
};

const LogoBlock: React.FC<{at: number}> = ({at}) => {
  const f = useCurrentFrame();
  const p = sp(f, at, 10);
  const n = sp(f, at + 6);
  return (
    <>
      <AppIcon size={300} style={{transform: `scale(${0.3 + 0.7 * p}) rotate(${(1 - p) * -120}deg)`}} />
      <div style={{fontFamily: font, fontWeight: 900, fontSize: 170, color: 'white', letterSpacing: -8, marginTop: 10, opacity: n, transform: `translateY(${(1 - n) * 60}px)`}}>
        Dialed
      </div>
    </>
  );
};

// ═══════════════════════════ Radial short (~12 s) ═══════════════════════════

export const RADIAL2_LEN = 372;

export const Radial2: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const D = 66; // drop
  const beats = beatGrid(D, 12, BEAT);
  const triple = [24, 30, 36];
  const turns = [D + 28, D + 28 + BEAT, D + 28 + BEAT * 2].map(Math.round);
  const pressAt = Math.round(D + 28 + BEAT * 3);
  const SCROLL_AT = pressAt + 18;
  const scrollClicks = [SCROLL_AT + 14, SCROLL_AT + 28, SCROLL_AT + 42, SCROLL_AT + 56];
  const END_AT = SCROLL_AT + 74;
  const hl = clicksSoFar(f, turns.slice(0, 2)) - clicksSoFar(f, [turns[2]]); // Volume → Scroll → Media → back to Scroll
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Music dropAt={D} total={RADIAL2_LEN} />
      {f < D ? (
        <Camera push={0.08} shake={interpolate(f, [40, D], [0, 5], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}>
          <Background glowY={0.6} intensity={0.8} />
          <Top>
            <Eyebrow text={t.eyebrow} at={2} />
            <Slam text={t.rHook} at={6} size={100} hot={['triple-press', 'Triple-press']} />
          </Top>
          <Center y={280}>
            <RealCaseTop width={700} rotation={0} clicks={triple} glow={1.2} />
          </Center>
          {triple.map((a) => (
            <Sfx key={a} at={a} name="pop" volume={0.6} />
          ))}
        </Camera>
      ) : null}
      {show(f, D, SCROLL_AT) ? (
        <Camera beats={beats} push={0.05} from={D}>
          <Background intensity={1.4} />
          <Top y={SAFE.top - 10}>{f < pressAt ? <Slam key="t" text={t.rTurn} at={D + 2} size={76} /> : <Slam key="p" text={t.rPress} at={pressAt} size={76} hot={['Press']} />}</Top>
          <Center y={-20}>
            <RadialMenu items={RADIAL} highlight={hl} appear={sp(f, D, 12)} chosen={interpolate(f, [pressAt, pressAt + 6, pressAt + 16], [0, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})} size={780} />
          </Center>
          <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom - 270, display: 'flex', justifyContent: 'center', opacity: 0.95}}>
            <RealCaseTop width={360} rotation={clicksSoFar(f, turns) * 30} clicks={[...turns, pressAt]} />
          </div>
        </Camera>
      ) : null}
      <Flash at={D} length={10} />
      <Sfx at={D} name="boom" volume={0.6} />
      {turns.map((a) => (
        <Sfx key={a} at={a} name="tick" volume={0.55} />
      ))}
      <Sfx at={pressAt} name="click" volume={0.7} />
      {show(f, SCROLL_AT, END_AT) ? (
        <Whip inAt={SCROLL_AT} outAt={END_AT}>
          <Camera beats={beats} push={0.04} from={SCROLL_AT}>
            <Background intensity={1.2} />
            <Top y={SAFE.top - 10}>
              <Slam text={t.rDone} at={SCROLL_AT + 2} size={84} hot={['scrolls.', 'scroll']} />
            </Top>
            <Center y={-40}>
              <MacBook kind="scroll" steps={clicksSoFar(f, scrollClicks)} />
            </Center>
            <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom - 150, display: 'flex', justifyContent: 'center'}}>
              <RealCaseTop width={430} rotation={clicksSoFar(f, scrollClicks) * 30} clicks={scrollClicks} />
            </div>
          </Camera>
        </Whip>
      ) : null}
      {scrollClicks.map((a) => (
        <Sfx key={a} at={a} name="click" volume={0.45} />
      ))}
      {f >= END_AT ? <End lang={lang} at={END_AT} beats={beats} /> : null}
      <Flash at={END_AT} length={8} color={C.accent} />
    </AbsoluteFill>
  );
};

// ═══════════════════════════ Profiles short (~12 s) ═══════════════════════════

export const PROFILES2_LEN = 372;

export const Profiles2: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const D = 66;
  const beats = beatGrid(D, 12, BEAT);
  const SEGP = Math.round(BEAT * 2); // 55
  const apps = [
    {app: 'Keynote', mode: 'Slides', profile: 'Presentations', kind: 'slides' as ScreenKind, symbol: 'play.rectangle.fill'},
    {app: 'Safari', mode: 'Scroll', profile: 'Browsing', kind: 'scroll' as ScreenKind, symbol: 'arrow.up.and.down'},
    {app: 'QuickTime', mode: 'Video Seek', profile: 'Video', kind: 'video' as ScreenKind, symbol: 'film'},
  ];
  const END_TEXT = D + SEGP * 3; // 231
  const END_AT = END_TEXT + Math.round(BEAT * 1.5);
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Music dropAt={D} total={PROFILES2_LEN} />
      {f < D ? (
        <Camera push={0.08}>
          <Background glowY={0.6} intensity={0.8} />
          <Top>
            <Eyebrow text={t.eyebrow} at={2} />
            <Slam text={t.pHook} at={6} size={84} hot={['CMF', 'app', 'knows', 'jaanta']} />
          </Top>
          <Center y={300}>
            <RealCaseSide width={820} tiltY={interpolate(f, [0, D], [18, -8])} tiltX={8} />
          </Center>
        </Camera>
      ) : null}
      <Flash at={D} length={10} />
      <Sfx at={D} name="boom" volume={0.6} />
      {apps.map((a, i) => {
        const s = D + i * SEGP;
        if (!show(f, s - 1, s + SEGP + 1)) return null;
        const clicks = [s + 20, s + 20 + HALF, s + 20 + BEAT].map(Math.round);
        return (
          <Whip key={i} inAt={s} outAt={s + SEGP}>
            <Camera beats={beats} push={0.03} from={s}>
              <Background glowX={i % 2 ? 0.3 : 0.7} intensity={1.2} />
              <Top y={SAFE.top - 20}>
                <div style={{display: 'flex', gap: 18}}>
                  {apps.map((x, k) => (
                    <Chip key={x.app} label={x.app} hot={k === i} appear={1} size={38} />
                  ))}
                </div>
                <Slam text={`→ ${a.mode}`} at={s + 4} size={92} color={C.accent} />
              </Top>
              <Center y={40}>
                <div style={{position: 'relative'}}>
                  <MacBook kind={a.kind} steps={clicksSoFar(f, clicks)} />
                  <div style={{position: 'absolute', left: 0, right: 0, bottom: 90, display: 'flex', justifyContent: 'center'}}>
                    <HUD symbol={a.symbol} title={`Profile: ${a.profile}`} subtitle={`${a.mode} mode`} appear={sp(f, s + 8)} scale={2} />
                  </div>
                </div>
              </Center>
              <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom - 210, display: 'flex', justifyContent: 'center'}}>
                <RealCaseTop width={360} rotation={clicksSoFar(f, clicks) * 32 + i * 60} clicks={clicks} />
              </div>
            </Camera>
          </Whip>
        );
      })}
      {apps.map((_, i) => {
        const s = D + i * SEGP;
        return (
          <React.Fragment key={i}>
            <Sfx at={s} name="whoosh" volume={0.35} />
            {[s + 20, s + 20 + HALF, s + 20 + BEAT].map((c) => (
              <Sfx key={c} at={c} name="click" volume={0.4} />
            ))}
          </React.Fragment>
        );
      })}
      {show(f, END_TEXT, END_AT) ? (
        <Camera beats={beats} push={0.05} from={END_TEXT}>
          <Background intensity={1.4} />
          <Center>
            <Slam text={t.pEnd} at={END_TEXT + 1} size={150} hot={['Every', 'Har', 'app.']} />
          </Center>
        </Camera>
      ) : null}
      {f >= END_AT ? <End lang={lang} at={END_AT} beats={beats} /> : null}
      <Flash at={END_AT} length={8} color={C.accent} />
    </AbsoluteFill>
  );
};
