import React from 'react';
import {AbsoluteFill, Audio, interpolate, Sequence, spring, staticFile, useCurrentFrame} from 'remotion';
import {AppIcon, Background, Chip, HUD, RadialMenu} from './components';
import {Lang} from './copy';
import {copy2} from './copy2';
import {ClickPops, Counter, FlipIn, Particles, Rays, Sub, Words} from './fx';
import {ScreenKind} from './MacScreen';
import {beatGrid, Camera, Eyebrow, Flash, MacBook, RealCaseSide, RealCaseTop, Ring, Whip} from './motion';
import {C, font, SAFE} from './theme';

// Music: "Uplifting Bass" by Lily J (Mixkit Stock Music Free License).
// The drop is at 14.38 s in the track; kicks then land every ~0.923 s.
const DROP_IN_TRACK = 14.38;
const BEAT = 27.7; // frames per kick at 30 fps
const HALF = BEAT / 2;
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

/** Spring that starts at frame `at` (plain function, safe inside conditionals). */
const sp = (f: number, at: number, damping = 14) => spring({frame: f - at, fps: 30, config: {damping}});

const Music: React.FC<{dropAt: number; total: number}> = ({dropAt, total}) => (
  <Audio
    src={staticFile('music/uplifting-bass.mp3')}
    startFrom={Math.round(DROP_IN_TRACK * 30 - dropAt)}
    volume={(f) => interpolate(f, [0, 8, total - 40, total - 2], [0, 0.85, 0.85, 0], clamp)}
  />
);

type SfxName = 'click' | 'tick' | 'whoosh' | 'pop' | 'boom';
const Sfx: React.FC<{at: number; name: SfxName; volume?: number}> = ({at, name, volume = 0.5}) => (
  <Sequence from={Math.round(at)} durationInFrames={30} layout="none">
    <Audio src={staticFile(`sfx/${name}.wav`)} volume={volume} />
  </Sequence>
);
const SfxList: React.FC<{ats: number[]; name: SfxName; volume?: number}> = ({ats, name, volume}) => (
  <>
    {ats.map((a) => (
      <Sfx key={`${name}${a}`} at={a} name={name} volume={volume} />
    ))}
  </>
);

const Top: React.FC<{children: React.ReactNode; y?: number}> = ({children, y = SAFE.top + 10}) => (
  <div style={{position: 'absolute', left: SAFE.side - 30, right: SAFE.side - 30, top: y, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 22}}>{children}</div>
);
const Center: React.FC<{children: React.ReactNode; y?: number}> = ({children, y = 0}) => (
  <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', transform: `translateY(${y}px)`}}>{children}</AbsoluteFill>
);
const Bottom: React.FC<{children: React.ReactNode; bottom: number}> = ({children, bottom}) => (
  <div style={{position: 'absolute', left: 0, right: 0, bottom, display: 'flex', justifyContent: 'center'}}>{children}</div>
);
const show = (f: number, a: number, b: number) => f >= a && f < b;

/** Smooth count of clicks so far (each click eases in over ~6 frames). */
const clicksSoFar = (f: number, ats: number[]) => ats.reduce((s, a) => s + interpolate(f, [a, a + 6], [0, 1], clamp), 0);
const clicksAt = (start: number, n: number, gap = HALF) => Array.from({length: n}, (_, i) => Math.round(start + i * gap));

/** Camera + background glow + drifting embers. */
const Scene: React.FC<{children: React.ReactNode; beats?: number[]; from?: number; push?: number; shake?: number; glowX?: number; glowY?: number; intensity?: number}> = ({
  children,
  beats = [],
  from = 0,
  push = 0.04,
  shake = 0,
  glowX,
  glowY,
  intensity = 1.2,
}) => (
  <Camera beats={beats} push={push} from={from} shake={shake}>
    <Background glowX={glowX} glowY={glowY} intensity={intensity} />
    <Particles beats={beats} intensity={Math.min(1, intensity * 0.8)} />
    {children}
  </Camera>
);

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
  const icon = sp(f, at, 9);
  const cta = sp(f, at + 16, 10);
  const made = sp(f, at + 26);
  const shine = interpolate(f, [at + 20, at + 40], [-30, 130], clamp);
  return (
    <AbsoluteFill>
      <Scene beats={beats} from={at} glowY={0.42} intensity={1.3}>
        <Top y={SAFE.top - 20}>
          <Eyebrow text={t.only} at={at + 2} />
        </Top>
        <Center y={-50}>
          <div style={{position: 'relative'}}>
            <Ring at={at + 2} x={145} y={145} size={300} length={20} width={10} />
            <AppIcon size={290} style={{transform: `scale(${0.3 + 0.7 * icon}) rotate(${(1 - icon) * -200}deg)`, opacity: Math.min(1, icon * 2)}} />
          </div>
          <div style={{marginTop: 10}}>
            <Words text="Dialed" at={at + 6} size={160} />
          </div>
          <div style={{marginTop: 20, transform: `scale(${0.5 + 0.5 * cta})`, opacity: Math.min(1, cta * 2), position: 'relative', overflow: 'hidden', borderRadius: 999}}>
            <Chip label={t.cta} appear={1} hot size={52} />
            <div style={{position: 'absolute', top: 0, bottom: 0, left: `${shine}%`, width: '22%', background: 'linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,0.6), rgba(255,255,255,0))', transform: 'skewX(-20deg)'}} />
          </div>
          <div style={{marginTop: 26}}>
            <Sub text={`${t.ctaSub} · github.com/taqionvibe/dialed`} at={at + 22} size={36} />
          </div>
        </Center>
        <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom + 10, textAlign: 'center', fontFamily: font, fontSize: 32, fontWeight: 600, color: C.faint, opacity: made, transform: `translateY(${(1 - made) * 20}px)`}}>
          Made with <span style={{color: C.accent, display: 'inline-block', transform: `scale(${1 + 0.25 * Math.max(0, Math.sin(f / 4))})`}}>♥</span> by <span style={{color: 'white'}}>Taqi Saeed</span>
        </div>
      </Scene>
    </AbsoluteFill>
  );
};

const LogoBlock: React.FC<{at: number; tagline: string}> = ({at, tagline}) => {
  const f = useCurrentFrame();
  const p = sp(f, at, 9);
  return (
    <>
      <AppIcon size={300} style={{transform: `scale(${0.2 + 0.8 * p}) rotate(${(1 - p) * -240}deg)`, opacity: Math.min(1, p * 2)}} />
      <div style={{marginTop: 6}}>
        <Words text="Dialed" at={at + 5} size={170} stagger={0} />
      </div>
      <div style={{marginTop: 14}}>
        <Sub text={tagline} at={at + 14} size={44} />
      </div>
    </>
  );
};

/** Bottom-of-screen case that reacts to clicks, with a popping label per click. */
const ReactiveCase: React.FC<{clicks: number[]; width: number; bottom: number; label?: string; labels?: string[]; symbol?: string; baseRot?: number; arrows?: number}> = ({
  clicks,
  width,
  bottom,
  label,
  labels,
  symbol,
  baseRot = 0,
  arrows = 0.9,
}) => {
  const f = useCurrentFrame();
  return (
    <Bottom bottom={bottom}>
      <div style={{position: 'relative'}}>
        <RealCaseTop width={width} rotation={baseRot + clicksSoFar(f, clicks) * 32} clicks={clicks} glow={1} arrows={arrows} />
        <ClickPops clicks={clicks} label={label} labels={labels} symbol={symbol} x={width * 0.72} y={width * 0.22} />
      </div>
    </Bottom>
  );
};

// ═══════════════════════════ HERO (~30 s) ═══════════════════════════

const DROP = 270;
const CLARIFY_AT = DROP + 62;
const MONTAGE_AT = CLARIFY_AT + 70;
const SEG = Math.round(BEAT * 2); // 55
const KINDS: {kind: ScreenKind; symbol: string; hud: string; pop: string; level?: boolean}[] = [
  {kind: 'scroll', symbol: 'arrow.up.and.down', hud: 'Scroll', pop: 'arrow.down'},
  {kind: 'slides', symbol: 'play.rectangle.fill', hud: 'Slides', pop: 'arrow.right'},
  {kind: 'video', symbol: 'film', hud: 'Video Seek', pop: 'forward.fill'},
  {kind: 'brightness', symbol: 'sun.max.fill', hud: 'Brightness', pop: 'sun.min.fill', level: true},
  {kind: 'volume', symbol: 'speaker.wave.2.fill', hud: 'Volume', pop: 'speaker.plus.fill', level: true},
];
const RADIAL_AT = MONTAGE_AT + KINDS.length * SEG;
const FEAT_AT = RADIAL_AT + 80;
const END_AT = FEAT_AT + 82;
export const HERO2_LEN = END_AT + 80;

export const Hero2: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const beats = beatGrid(DROP, 26, BEAT);

  // Before the drop: volume clicks while "music volume" is on screen, then a build-up spin.
  const volClicks = [100, 112, 124];
  const build = interpolate(f, [214, DROP], [0, 1], clamp);
  const introRot = clicksSoFar(f, volClicks) * 26 + Math.pow(build, 2.2) * 720;
  const sad = interpolate(f, [150, 168, 200, 210], [0, 1, 1, 0], clamp);
  const clarifyClicks = clicksAt(CLARIFY_AT + 18, 3);

  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Music dropAt={DROP} total={HERO2_LEN} />

      {/* ── Owner hook ── */}
      {f < DROP ? (
        <Scene push={0.1} shake={build * 7} glowY={0.62} intensity={0.55 + build * 1.2}>
          <Top>
            <Eyebrow text={t.eyebrow} at={4} out={DROP - 6} />
            {show(f, 8, 80) ? (
              <>
                <Words text={t.own1} at={8} size={104} hot={t.own1Hot} out={70} />
                <Sub text={t.own1Sub} at={26} out={70} />
              </>
            ) : null}
            {show(f, 78, 150) ? (
              <>
                <Words text={t.own2} at={80} size={86} hot={t.own2Hot} out={142} />
                <Sub text={t.own2Sub} at={98} out={142} />
              </>
            ) : null}
            {show(f, 148, 208) ? (
              <>
                <Words text={t.own3} at={150} size={104} out={200} />
                <Sub text={t.own3Sub} at={162} out={200} />
              </>
            ) : null}
            {show(f, 206, DROP) ? (
              <>
                <Words text={t.build} at={208} size={90} hot={t.buildHot} />
                <Sub text={t.buildSub} at={226} />
              </>
            ) : null}
          </Top>
          {f < 80 ? (
            <Center y={300}>
              <div style={{opacity: interpolate(f, [0, 8, 72, 80], [0, 1, 1, 0], clamp), transform: `translateY(${interpolate(f, [0, 30], [140, 0], {...clamp, easing: (x) => 1 - Math.pow(1 - x, 3)})}px) scale(${interpolate(f, [0, 80], [0.9, 1.05])})`}}>
                <RealCaseSide width={900} tiltY={interpolate(f, [0, 80], [-70, 25])} tiltX={interpolate(f, [0, 80], [14, 0])} dial={f * 1.2} />
              </div>
            </Center>
          ) : (
            <Center y={320}>
              <div
                style={{
                  opacity: interpolate(f, [78, 86], [0, 1], clamp),
                  transform: `scale(${interpolate(f, [78, 96, 150, 170, 214, DROP], [0.7, 1, 1, 0.86, 0.95, 1.3], clamp)}) rotate(${sad * -8}deg)`,
                  filter: sad > 0 ? `grayscale(${sad * 0.9}) brightness(${1 - sad * 0.25})` : undefined,
                }}
              >
                <div style={{position: 'relative'}}>
                  <RealCaseTop width={720} rotation={introRot} clicks={volClicks} glow={0.4 + build * 1.8} arrows={f < 150 || f > 214 ? 1 : 0} />
                  <ClickPops clicks={volClicks} labels={['Vol +', 'Vol +', 'Vol −']} symbol="speaker.wave.2.fill" x={500} y={150} />
                </div>
              </div>
            </Center>
          )}
          <SfxList ats={[8, 80, 150, 208]} name="whoosh" volume={0.25} />
          <SfxList ats={volClicks} name="click" volume={0.55} />
        </Scene>
      ) : null}

      {/* ── Drop: "It can now." → logo ── */}
      {show(f, DROP, CLARIFY_AT) ? (
        <Scene beats={beats} from={DROP} push={0.07} glowY={0.45} intensity={1.7}>
          <Rays at={DROP} y={860} length={46} />
          <Center y={-140}>
            <div style={{opacity: interpolate(f, [DROP + 20, DROP + 26], [1, 0], clamp)}}>
              <Words text={t.drop} at={DROP} size={150} stagger={2} color={C.accent} />
            </div>
          </Center>
          <Center y={-60}>
            <div style={{opacity: f >= DROP + 22 ? 1 : 0, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
              <LogoBlock at={DROP + 22} tagline={t.tagline} />
            </div>
          </Center>
          <div style={{position: 'absolute', left: 540, top: 860}}>
            <Ring at={DROP} x={0} y={0} size={520} length={24} width={16} />
            <Ring at={DROP + 4} x={0} y={0} size={320} length={22} width={8} color="white" />
            <Ring at={DROP + 22} x={0} y={-60} size={420} length={20} width={10} />
          </div>
        </Scene>
      ) : null}
      <Flash at={DROP} length={12} />
      <Sfx at={DROP} name="boom" volume={0.7} />
      <Sfx at={DROP + 22} name="pop" volume={0.5} />

      {/* ── A free Mac app for your CMF dial ── */}
      {show(f, CLARIFY_AT, MONTAGE_AT) ? (
        <Whip inAt={CLARIFY_AT} outAt={MONTAGE_AT}>
          <Scene beats={beats} from={CLARIFY_AT} glowY={0.62}>
            <Top>
              <Words text={t.clarify} at={CLARIFY_AT + 2} size={78} hot={t.clarifyHot} />
              <Sub text={t.clarifySub} at={CLARIFY_AT + 16} />
            </Top>
            <Center y={300}>
              <div style={{position: 'relative', transform: `scale(${0.8 + 0.2 * sp(f, CLARIFY_AT + 4, 10)})`}}>
                <RealCaseTop width={700} rotation={clicksSoFar(f, clarifyClicks) * 30} clicks={clarifyClicks} glow={1.3} arrows={1} />
                <ClickPops clicks={clarifyClicks} labels={['Scroll', 'Slides', 'Video']} x={490} y={150} />
              </div>
            </Center>
          </Scene>
        </Whip>
      ) : null}
      <Sfx at={CLARIFY_AT} name="whoosh" volume={0.35} />
      <SfxList ats={clarifyClicks} name="click" volume={0.45} />

      {/* ── Five modes, one per two beats ── */}
      {KINDS.map((m, i) => {
        const a = MONTAGE_AT + i * SEG;
        if (!show(f, a - 1, a + SEG + 1)) return null;
        const clicks = clicksAt(a + 10, 4);
        const steps = clicksSoFar(f, clicks);
        const level = m.kind === 'brightness' ? Math.max(0.15, 1 - steps * 0.2) : Math.min(1, 0.3 + steps * 0.17);
        return (
          <Whip key={i} inAt={a} outAt={a + SEG}>
            <Scene beats={beats} from={a} push={0.03} glowX={i % 2 ? 0.3 : 0.7} glowY={0.5}>
              <Top y={SAFE.top - 30}>
                <Words text={t.montage[i]} at={a + 1} size={92} hot={i === 0 ? ['anything', 'scroll'] : []} />
                <Sub text={t.montageSub[i]} at={a + 9} size={40} />
              </Top>
              <Center y={-100}>
                <FlipIn at={a + 2} from={i % 2 ? 'left' : 'right'}>
                  <div style={{position: 'relative'}}>
                    <MacBook kind={m.kind} steps={steps} />
                    <div style={{position: 'absolute', left: 0, right: 0, bottom: 90, display: 'flex', justifyContent: 'center'}}>
                      <HUD symbol={m.symbol} title={m.hud} level={m.level ? level : undefined} subtitle={m.level ? `${Math.round(level * 100)}%` : undefined} appear={sp(f, a + 10)} scale={2} />
                    </div>
                  </div>
                </FlipIn>
              </Center>
              <ReactiveCase clicks={clicks} width={440} bottom={SAFE.bottom - 170} label={t.pops[i]} symbol={m.pop} baseRot={i * 50} />
            </Scene>
          </Whip>
        );
      })}
      {KINDS.map((_, i) => {
        const a = MONTAGE_AT + i * SEG;
        return (
          <React.Fragment key={i}>
            <Sfx at={a} name="whoosh" volume={0.35} />
            <SfxList ats={clicksAt(a + 10, 4)} name="click" volume={0.42} />
          </React.Fragment>
        );
      })}

      {/* ── Radial menu ── */}
      {show(f, RADIAL_AT, FEAT_AT) ? (
        <Whip inAt={RADIAL_AT} outAt={FEAT_AT}>
          <Scene beats={beats} from={RADIAL_AT} intensity={1.3}>
            <Top y={SAFE.top - 30}>
              <Words text={t.radial} at={RADIAL_AT + 1} size={86} hot={t.radialHot} />
              <Sub text={t.radialSub} at={RADIAL_AT + 14} size={40} />
            </Top>
            <Center y={170}>
              <div style={{transform: `rotate(${(1 - sp(f, RADIAL_AT + 4, 12)) * -90}deg)`}}>
                <RadialMenu items={RADIAL} highlight={clicksSoFar(f, clicksAt(RADIAL_AT + 24, 4))} appear={sp(f, RADIAL_AT + 4, 12)} size={840} />
              </div>
            </Center>
          </Scene>
        </Whip>
      ) : null}
      <Sfx at={RADIAL_AT} name="whoosh" volume={0.35} />
      <SfxList ats={[RADIAL_AT + 4, RADIAL_AT + 8, RADIAL_AT + 12]} name="pop" volume={0.35} />
      <SfxList ats={clicksAt(RADIAL_AT + 24, 4)} name="tick" volume={0.5} />

      {/* ── 11 modes + features ── */}
      {show(f, FEAT_AT, END_AT) ? (
        <Scene beats={beats} from={FEAT_AT} glowY={0.45} intensity={1.3}>
          <Center y={-60}>
            <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 26}}>
              <div style={{display: 'flex', alignItems: 'baseline', gap: 24}}>
                <Counter at={FEAT_AT + 2} to={11} size={250} />
                <Words text={t.featHead.replace(', ', ',\n')} at={FEAT_AT + 10} size={70} />
              </div>
              {t.features.map((label, i) => (
                <FlipIn key={label} at={FEAT_AT + 22 + Math.round(i * HALF)} from={i % 2 ? 'right' : 'left'}>
                  <Chip symbol={['person.crop.rectangle.stack', 'wand.and.stars', 'arrow.clockwise'][i]} label={label} hot={i === 0} size={54} appear={1} />
                </FlipIn>
              ))}
            </div>
          </Center>
        </Scene>
      ) : null}
      <Sfx at={FEAT_AT} name="whoosh" volume={0.35} />
      <SfxList ats={[0, 1, 2].map((i) => FEAT_AT + 22 + Math.round(i * HALF))} name="pop" volume={0.35} />

      {f >= END_AT ? <End lang={lang} at={END_AT} beats={beats} /> : null}
      <Flash at={END_AT} length={8} color={C.accent} />
      <Sfx at={END_AT} name="boom" volume={0.45} />
    </AbsoluteFill>
  );
};

// ═══════════════════════════ Radial short (~13 s) ═══════════════════════════

const RD = 84; // drop
const R_TURNS = clicksAt(RD + 30, 3, BEAT);
const R_PRESS = Math.round(RD + 30 + BEAT * 3);
const R_SCROLL = R_PRESS + 20;
const R_SCROLL_CLICKS = clicksAt(R_SCROLL + 14, 4);
const R_END = R_SCROLL + 76;
export const RADIAL2_LEN = R_END + 85;

export const Radial2: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const beats = beatGrid(RD, 14, BEAT);
  const triple = [44, 50, 56];
  const hl = clicksSoFar(f, R_TURNS.slice(0, 2)) - clicksSoFar(f, [R_TURNS[2]]); // Volume → Scroll → Media → Scroll
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Music dropAt={RD} total={RADIAL2_LEN} />
      {f < RD ? (
        <Scene push={0.1} shake={interpolate(f, [60, RD], [0, 6], clamp)} glowY={0.62} intensity={0.8}>
          <Top>
            <Eyebrow text={t.eyebrow} at={2} />
            <Words text={t.rHook} at={6} size={100} hot={t.rHookHot} />
            <Sub text={t.rHookSub} at={24} />
          </Top>
          <Center y={320}>
            <div style={{position: 'relative', transform: `scale(${interpolate(f, [0, 14], [0.7, 1], clamp)})`}}>
              <RealCaseTop width={720} rotation={0} clicks={triple} glow={1.2} />
              <ClickPops clicks={triple} labels={['1', '2', '3']} x={500} y={160} />
            </div>
          </Center>
          <SfxList ats={triple} name="pop" volume={0.6} />
          <Sfx at={6} name="whoosh" volume={0.25} />
        </Scene>
      ) : null}
      {show(f, RD, R_SCROLL) ? (
        <Scene beats={beats} from={RD} intensity={1.4}>
          <Rays at={RD} y={900} length={36} />
          <Top y={SAFE.top - 30}>
            {f < R_PRESS ? (
              <React.Fragment key="turn">
                <Words text={t.rTurn} at={RD + 2} size={78} />
                <Sub text={t.rTurnSub} at={RD + 14} size={40} />
              </React.Fragment>
            ) : (
              <React.Fragment key="press">
                <Words text={t.rPress} at={R_PRESS} size={78} hot={['Press']} />
                <Sub text={t.rPressSub} at={R_PRESS + 6} size={40} />
              </React.Fragment>
            )}
          </Top>
          <Center y={-10}>
            <div style={{transform: `rotate(${(1 - sp(f, RD, 12)) * -120}deg)`}}>
              <RadialMenu items={RADIAL} highlight={hl} appear={sp(f, RD, 12)} chosen={interpolate(f, [R_PRESS, R_PRESS + 6, R_PRESS + 16], [0, 1, 0], clamp)} size={760} />
            </div>
          </Center>
          <ReactiveCase clicks={[...R_TURNS, R_PRESS]} width={380} bottom={SAFE.bottom - 290} labels={['Scroll', 'Media', 'Scroll', '✓ Scroll']} />
        </Scene>
      ) : null}
      <Flash at={RD} length={10} />
      <Sfx at={RD} name="boom" volume={0.6} />
      <SfxList ats={R_TURNS} name="tick" volume={0.55} />
      <Sfx at={R_PRESS} name="click" volume={0.7} />
      {show(f, R_SCROLL, R_END) ? (
        <Whip inAt={R_SCROLL} outAt={R_END}>
          <Scene beats={beats} from={R_SCROLL}>
            <Top y={SAFE.top - 30}>
              <Words text={t.rDone} at={R_SCROLL + 2} size={84} hot={t.rDoneHot} />
              <Sub text={t.rDoneSub} at={R_SCROLL + 14} size={40} />
            </Top>
            <Center y={-80}>
              <FlipIn at={R_SCROLL + 2}>
                <MacBook kind="scroll" steps={clicksSoFar(f, R_SCROLL_CLICKS)} />
              </FlipIn>
            </Center>
            <ReactiveCase clicks={R_SCROLL_CLICKS} width={440} bottom={SAFE.bottom - 170} label="Scroll" symbol="arrow.down" />
          </Scene>
        </Whip>
      ) : null}
      <Sfx at={R_SCROLL} name="whoosh" volume={0.35} />
      <SfxList ats={R_SCROLL_CLICKS} name="click" volume={0.45} />
      {f >= R_END ? <End lang={lang} at={R_END} beats={beats} /> : null}
      <Flash at={R_END} length={8} color={C.accent} />
      <Sfx at={R_END} name="boom" volume={0.45} />
    </AbsoluteFill>
  );
};

// ═══════════════════════════ Profiles short (~13 s) ═══════════════════════════

const PD = 84;
const SEGP = Math.round(BEAT * 2); // 55
const P_END_TEXT = PD + SEGP * 3;
const P_END = P_END_TEXT + Math.round(BEAT * 1.6);
export const PROFILES2_LEN = P_END + 85;

export const Profiles2: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy2[lang];
  const beats = beatGrid(PD, 14, BEAT);
  const apps = [
    {app: 'Keynote', mode: 'Slides', profile: 'Presentations', kind: 'slides' as ScreenKind, symbol: 'play.rectangle.fill', pop: 'arrow.right', popLabel: t.pops[1]},
    {app: 'Safari', mode: 'Scroll', profile: 'Browsing', kind: 'scroll' as ScreenKind, symbol: 'arrow.up.and.down', pop: 'arrow.down', popLabel: t.pops[0]},
    {app: 'QuickTime', mode: 'Video Seek', profile: 'Video', kind: 'video' as ScreenKind, symbol: 'film', pop: 'forward.fill', popLabel: t.pops[2]},
  ];
  const openLine = (app: string, mode: string) => (lang === 'en' ? `${t.pOpen} ${app} → ${mode} mode` : `${app} ${t.pOpen} → ${mode} mode`);
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Music dropAt={PD} total={PROFILES2_LEN} />
      {f < PD ? (
        <Scene push={0.1} glowY={0.62} intensity={0.8} shake={interpolate(f, [60, PD], [0, 5], clamp)}>
          <Top>
            <Eyebrow text={t.eyebrow} at={2} />
            <Words text={t.pHook} at={6} size={82} hot={t.pHookHot} />
            <Sub text={t.pHookSub} at={28} size={40} />
          </Top>
          <Center y={360}>
            <RealCaseSide width={820} tiltY={interpolate(f, [0, PD], [40, -40])} tiltX={8} dial={f * 2} />
          </Center>
          <Sfx at={6} name="whoosh" volume={0.25} />
        </Scene>
      ) : null}
      <Flash at={PD} length={10} />
      <Sfx at={PD} name="boom" volume={0.6} />
      {apps.map((a, i) => {
        const s = PD + i * SEGP;
        if (!show(f, s - 1, s + SEGP + 1)) return null;
        const clicks = clicksAt(s + 18, 3);
        return (
          <Whip key={i} inAt={s} outAt={s + SEGP}>
            <Scene beats={beats} from={s} push={0.03} glowX={i % 2 ? 0.3 : 0.7}>
              {i === 0 ? <Rays at={PD} y={900} length={36} /> : null}
              <Top y={SAFE.top - 40}>
                <div style={{display: 'flex', gap: 18}}>
                  {apps.map((x, k) => {
                    const p = sp(f, s + k * 3, 10);
                    return (
                      <div key={x.app} style={{transform: `scale(${(k === i ? 1.12 : 0.95) * (0.6 + 0.4 * p)})`, opacity: p}}>
                        <Chip label={x.app} hot={k === i} appear={1} size={38} />
                      </div>
                    );
                  })}
                </div>
                <Words text={`→ ${a.mode}`} at={s + 4} size={92} color={C.accent} />
                <Sub text={openLine(a.app, a.mode)} at={s + 12} size={40} />
              </Top>
              <Center y={30}>
                <FlipIn at={s + 3} from={i % 2 ? 'left' : 'right'}>
                  <div style={{position: 'relative'}}>
                    <MacBook kind={a.kind} steps={clicksSoFar(f, clicks)} />
                    <div style={{position: 'absolute', left: 0, right: 0, bottom: 90, display: 'flex', justifyContent: 'center'}}>
                      <HUD symbol={a.symbol} title={`Profile: ${a.profile}`} subtitle={`${a.mode} mode`} appear={sp(f, s + 10)} scale={2} />
                    </div>
                  </div>
                </FlipIn>
              </Center>
              <ReactiveCase clicks={clicks} width={380} bottom={SAFE.bottom - 290} label={a.popLabel} symbol={a.pop} baseRot={i * 60} />
            </Scene>
          </Whip>
        );
      })}
      {apps.map((_, i) => {
        const s = PD + i * SEGP;
        return (
          <React.Fragment key={i}>
            <Sfx at={s} name="whoosh" volume={0.35} />
            <SfxList ats={clicksAt(s + 18, 3)} name="click" volume={0.4} />
          </React.Fragment>
        );
      })}
      {show(f, P_END_TEXT, P_END) ? (
        <Scene beats={beats} from={P_END_TEXT} intensity={1.4}>
          <Center y={-40}>
            <Words text={t.pEnd} at={P_END_TEXT + 1} size={150} hot={t.pEndHot} stagger={4} />
            <div style={{marginTop: 30}}>
              <Sub text={t.pEndSub} at={P_END_TEXT + 16} size={44} />
            </div>
          </Center>
        </Scene>
      ) : null}
      <Sfx at={P_END_TEXT} name="pop" volume={0.45} />
      {f >= P_END ? <End lang={lang} at={P_END} beats={beats} /> : null}
      <Flash at={P_END} length={8} color={C.accent} />
      <Sfx at={P_END} name="boom" volume={0.45} />
    </AbsoluteFill>
  );
};
