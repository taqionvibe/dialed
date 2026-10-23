import React from 'react';
import {AbsoluteFill, Audio, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {AppIcon, Background, CaseDial, Chip, HUD, Kinetic, RadialMenu} from './components';
import {copy, Lang} from './copy';
import {MacScreen, ScreenKind} from './MacScreen';
import {C, font, SAFE} from './theme';

// ───────────────────────── helpers ─────────────────────────

const Sfx: React.FC<{at: number; name: 'click' | 'tick' | 'whoosh' | 'pop' | 'boom'; volume?: number}> = ({at, name, volume = 0.8}) => (
  <Sequence from={at} durationInFrames={30} layout="none">
    <Audio src={staticFile(`sfx/${name}.wav`)} volume={volume} />
  </Sequence>
);

/** Sum of springs: a smooth count of how many of `ats` have happened by now. */
const useSteps = (ats: number[]) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  return ats.reduce((sum, a) => sum + spring({frame: f - a, fps, config: {damping: 16, mass: 0.6}}), 0);
};

const useIn = (at: number, damping = 14) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({frame: f - at, fps, config: {damping}});
};

const fadeOut = (f: number, at: number, len = 10) => interpolate(f, [at, at + len], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

const Top: React.FC<{children: React.ReactNode; y?: number}> = ({children, y = SAFE.top + 40}) => (
  <div style={{position: 'absolute', left: SAFE.side, right: SAFE.side, top: y, display: 'flex', justifyContent: 'center'}}>{children}</div>
);

const Center: React.FC<{children: React.ReactNode; y?: number}> = ({children, y = 0}) => (
  <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', transform: `translateY(${y}px)`}}>{children}</AbsoluteFill>
);

const RADIAL_ITEMS = (lang: Lang) => {
  const t = copy[lang];
  return [
    {symbol: 'speaker.wave.2.fill', label: 'Volume', hint: t.turn},
    {symbol: 'arrow.up.and.down', label: 'Scroll', hint: t.turn},
    {symbol: 'music.note', label: 'Media'},
    {symbol: 'film', label: 'Video Seek'},
    {symbol: 'sun.max.fill', label: 'Brightness'},
    {symbol: 'plus.magnifyingglass', label: 'Zoom'},
    {symbol: 'square.on.square', label: 'Browser Tabs'},
    {symbol: 'square.grid.2x2.fill', label: 'App Switcher'},
    {symbol: 'arrow.uturn.backward', label: 'Undo / Redo'},
  ];
};

/** Shared closing card. */
export const EndCard: React.FC<{lang: Lang; at: number; headline?: string}> = ({lang, at, headline}) => {
  const f = useCurrentFrame();
  const t = copy[lang];
  const icon = useIn(at + 2, 11);
  const name = useIn(at + 10);
  const cta = useIn(at + 18);
  const made = useIn(at + 28);
  return (
    <AbsoluteFill>
      <Background glowY={0.4} intensity={1.2} />
      <Sfx at={at + 2} name="boom" volume={0.9} />
      {headline ? (
        <Top y={SAFE.top + 10}>
          <Kinetic text={headline} at={at} size={64} weight={800} color={C.dim} />
        </Top>
      ) : null}
      <Center y={-80}>
        <AppIcon size={300} style={{transform: `scale(${0.6 + 0.4 * icon}) rotate(${(1 - icon) * -40}deg)`, opacity: icon}} />
        <div style={{fontFamily: font, fontWeight: 900, fontSize: 150, color: 'white', letterSpacing: -6, marginTop: 20, opacity: name, transform: `translateY(${(1 - name) * 40}px)`}}>
          Dialed
        </div>
        <div style={{marginTop: 26, opacity: cta, transform: `translateY(${(1 - cta) * 30}px)`}}>
          <Chip label={t.cta} appear={1} hot size={44} />
        </div>
        <div style={{fontFamily: font, fontSize: 34, fontWeight: 600, color: C.dim, marginTop: 26, opacity: cta}}>
          {t.ctaSub} · github.com/taqionvibe/dialed
        </div>
      </Center>
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: SAFE.bottom + 20,
          textAlign: 'center',
          fontFamily: font,
          fontSize: 32,
          fontWeight: 600,
          color: C.faint,
          opacity: made * fadeOut(f, 100000),
        }}
      >
        Made with <span style={{color: C.accent}}>♥</span> by <span style={{color: 'white'}}>Taqi Saeed</span>
      </div>
    </AbsoluteFill>
  );
};

// ───────────────────────── Hero reel (~21 s) ─────────────────────────

const MONTAGE: {kind: ScreenKind; symbol: string; hud: string; level?: boolean}[] = [
  {kind: 'scroll', symbol: 'arrow.up.and.down', hud: 'Scroll'},
  {kind: 'slides', symbol: 'play.rectangle.fill', hud: 'Slides'},
  {kind: 'video', symbol: 'film', hud: 'Video Seek'},
  {kind: 'brightness', symbol: 'sun.max.fill', hud: 'Brightness', level: true},
  {kind: 'volume', symbol: 'speaker.wave.2.fill', hud: 'Volume', level: true},
];
const SEG = 36;
const MONTAGE_AT = 330;

export const HeroReel: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy[lang];

  // Scene 1–2: the case and the hook.
  const caseIn = useIn(4, 12);
  const caseClicks = useSteps([24, 38, 52, 96, 110]);
  const caseOut = fadeOut(f, 132, 14);

  // Scene 3–4: "Until now." → logo.
  const until = f >= 140 && f < 205;
  const logoIn = useIn(176, 11);
  const logoOut = fadeOut(f, 252, 10);

  // Scene 5: radial menu.
  const radialIn = useIn(262, 13);
  const radialSteps = useSteps([284, 298, 312]);
  const chosen = interpolate(f, [322, 328, 336], [0, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const radialOut = fadeOut(f, 326, 8);

  // Scene 6: montage.
  const segIndex = Math.floor((f - MONTAGE_AT) / SEG);
  const inMontage = f >= MONTAGE_AT && segIndex < MONTAGE.length;
  const segStart = MONTAGE_AT + segIndex * SEG;
  const segSteps = useSteps([segStart + 8, segStart + 17, segStart + 26]);
  const steps = inMontage ? segSteps : 0;

  // Scene 7: features. Scene 8: end card.
  const FEAT_AT = MONTAGE_AT + MONTAGE.length * SEG; // 510
  const END_AT = FEAT_AT + 48; // 558

  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Background glowY={f < 140 ? 0.62 : 0.45} />

      {/* Scene 1–2 */}
      {f < 146 ? (
        <>
          <Top>
            <div style={{position: 'relative', width: '100%'}}>
              {f < 84 ? <Kinetic text={t.hook1} at={6} size={84} highlight={['dial', 'dial.']} out={74} /> : null}
              {f >= 80 ? <Kinetic text={t.hook2} at={84} size={84} highlight={['Mac', 'never', 'anjaan']} out={132} /> : null}
            </div>
          </Top>
          <Center y={170}>
            <div style={{opacity: caseIn * caseOut, transform: `scale(${0.8 + 0.2 * caseIn})`, filter: f > 84 ? `saturate(${interpolate(f, [84, 110], [1, 0.25], {extrapolateRight: 'clamp'})})` : undefined}}>
              <CaseDial rotation={caseClicks * 28} pulse={(caseClicks % 1)} />
            </div>
          </Center>
          {[24, 38, 52, 96, 110].map((a) => (
            <Sfx key={a} at={a} name="click" volume={0.7} />
          ))}
        </>
      ) : null}

      {/* Scene 3 */}
      {until ? (
        <Center y={-40}>
          <div style={{transform: `scale(${interpolate(f, [176, 200], [1, 1.25], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})})`, opacity: fadeOut(f, 180, 12)}}>
            <Kinetic text={t.hook3} at={142} size={150} weight={900} color={C.accent} stagger={5} />
          </div>
        </Center>
      ) : null}
      <Sfx at={142} name="whoosh" volume={0.6} />

      {/* Scene 4: logo */}
      {f >= 176 && f < 264 ? (
        <Center y={-60}>
          <div style={{opacity: logoIn * logoOut, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
            <AppIcon size={330} style={{transform: `scale(${0.5 + 0.5 * logoIn}) rotate(${(1 - logoIn) * -60}deg)`}} />
            <div style={{fontFamily: font, fontWeight: 900, fontSize: 160, color: 'white', letterSpacing: -7, marginTop: 16}}>Dialed</div>
            <div style={{fontFamily: font, fontWeight: 600, fontSize: 44, color: C.dim, textAlign: 'center', whiteSpace: 'pre-line', marginTop: 10, lineHeight: 1.25}}>
              {t.tagline}
            </div>
          </div>
        </Center>
      ) : null}
      <Sfx at={176} name="boom" volume={0.95} />

      {/* Scene 5: radial */}
      {f >= 258 && f < 340 ? (
        <>
          <Top>
            <Chip symbol="circle.circle" label={`${t.triple} → radial`} appear={radialIn * radialOut} size={42} />
          </Top>
          <Center y={60}>
            <div style={{opacity: radialOut}}>
              <RadialMenu items={RADIAL_ITEMS(lang)} highlight={radialSteps} appear={radialIn} chosen={chosen} />
            </div>
          </Center>
          {[262, 266, 270].map((a) => (
            <Sfx key={a} at={a} name="pop" volume={0.5} />
          ))}
          {[284, 298, 312].map((a) => (
            <Sfx key={a} at={a} name="tick" volume={0.7} />
          ))}
          <Sfx at={322} name="whoosh" volume={0.5} />
        </>
      ) : null}

      {/* Scene 6: montage */}
      {inMontage ? (
        <Montage lang={lang} index={segIndex} start={segStart} steps={steps} />
      ) : null}
      {MONTAGE.map((_, i) =>
        [8, 17, 26].map((o) => <Sfx key={`${i}-${o}`} at={MONTAGE_AT + i * SEG + o} name="click" volume={0.65} />),
      )}

      {/* Scene 7: features */}
      {f >= FEAT_AT && f < END_AT + 6 ? <Features lang={lang} at={FEAT_AT} out={END_AT - 4} /> : null}

      {/* Scene 8: end card */}
      {f >= END_AT ? <EndCard lang={lang} at={END_AT} /> : null}
    </AbsoluteFill>
  );
};

const Montage: React.FC<{lang: Lang; index: number; start: number; steps: number}> = ({lang, index, start, steps}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = copy[lang];
  const m = MONTAGE[index];
  const appear = spring({frame: f - start, fps, config: {damping: 15}});
  const out = fadeOut(f, start + SEG - 5, 5);
  const level = m.kind === 'brightness' ? Math.max(0.12, 1 - steps * 0.22) : Math.min(1, 0.35 + steps * 0.15);
  return (
    <AbsoluteFill style={{opacity: out}}>
      <Top>
        <Kinetic key={index} text={t.montage[index]} at={start} size={92} weight={800} stagger={2} />
      </Top>
      <Center y={-50}>
        <MacScreen kind={m.kind} steps={steps} appear={appear} />
      </Center>
      <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom - 40, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 30}}>
        <MiniDial rotation={steps * 28 + index * 40} pulse={steps % 1} />
        <HUD symbol={m.symbol} title={m.hud} level={m.level ? level : undefined} subtitle={m.level ? `${Math.round(level * 100)}%` : t.turn} appear={appear} scale={1.95} />
      </div>
    </AbsoluteFill>
  );
};

/** The case scaled down with a correctly sized layout box. */
const MiniDial: React.FC<{rotation: number; pulse: number}> = ({rotation, pulse}) => (
  <div style={{position: 'relative', width: 620 * 0.34, height: 520 * 0.34}}>
    <div style={{position: 'absolute', left: 0, top: 0, transform: 'scale(0.34)', transformOrigin: 'top left'}}>
      <CaseDial rotation={rotation} pulse={pulse} />
    </div>
  </div>
);

const Features: React.FC<{lang: Lang; at: number; out: number}> = ({lang, at, out}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = copy[lang];
  const icons = ['dial.medium.fill', 'person.crop.rectangle.stack', 'wand.and.stars', 'arrow.clockwise'];
  return (
    <AbsoluteFill style={{opacity: fadeOut(f, out, 8)}}>
      <Center>
        <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28}}>
          {t.features.map((label, i) => (
            <Chip key={label} symbol={icons[i]} label={label} hot={i === 0} size={50} appear={spring({frame: f - at - i * 5, fps, config: {damping: 13}})} />
          ))}
        </div>
      </Center>
      {t.features.map((_, i) => (
        <Sfx key={i} at={at + i * 5} name="pop" volume={0.45} />
      ))}
    </AbsoluteFill>
  );
};

// ───────────────────────── Short reel: radial (~9 s) ─────────────────────────

export const RadialReel: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const t = copy[lang];
  const caseIn = useIn(2, 12);
  const triple = [22, 27, 32];
  const pulses = useSteps(triple);
  const radialIn = useIn(48, 13);
  const turns = [74, 92, 112];
  const forward = useSteps([74, 92]);
  const back = useSteps([112]);
  const hl = forward - back; // Volume → Scroll → Media, then back to Scroll
  const chosen = interpolate(f, [150, 156, 166], [0, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const scroll = useSteps([186, 196, 206, 216]);
  const screenIn = useIn(172);
  const END = 238;
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Background />
      {f < 50 ? (
        <>
          <Top>
            <Kinetic text={t.rHook} at={2} size={88} highlight={['triple-press', 'Triple-press']} out={42} />
          </Top>
          <Center y={160}>
            <div style={{opacity: caseIn * fadeOut(f, 42, 8), transform: `scale(${0.8 + 0.2 * caseIn})`}}>
              <CaseDial rotation={0} pulse={pulses % 1} />
            </div>
          </Center>
          {triple.map((a) => (
            <Sfx key={a} at={a} name="pop" volume={0.7} />
          ))}
        </>
      ) : null}
      {f >= 46 && f < 176 ? (
        <>
          <Top>
            {f < 146 ? <Kinetic key="turn" text={t.rTurn} at={56} size={72} /> : <Kinetic key="press" text={t.rPress} at={146} size={72} highlight={['Press']} />}
          </Top>
          <Center y={60}>
            <div style={{opacity: fadeOut(f, 166, 10)}}>
              <RadialMenu items={RADIAL_ITEMS(lang)} highlight={hl} appear={radialIn} chosen={chosen} />
            </div>
          </Center>
          <Sfx at={48} name="whoosh" volume={0.5} />
          {turns.map((a) => (
            <Sfx key={a} at={a} name="tick" volume={0.7} />
          ))}
          <Sfx at={150} name="click" volume={0.9} />
        </>
      ) : null}
      {f >= 172 && f < END + 4 ? (
        <AbsoluteFill style={{opacity: fadeOut(f, END - 4, 8)}}>
          <Top>
            <Kinetic text={t.rDone} at={174} size={76} highlight={['scroll', 'scrolls.']} />
          </Top>
          <Center y={60}>
            <MacScreen kind="scroll" steps={scroll} appear={screenIn} />
          </Center>
          {[186, 196, 206, 216].map((a) => (
            <Sfx key={a} at={a} name="click" volume={0.65} />
          ))}
        </AbsoluteFill>
      ) : null}
      {f >= END ? <EndCard lang={lang} at={END} /> : null}
    </AbsoluteFill>
  );
};

// ───────────────────────── Short reel: profiles (~10 s) ─────────────────────────

export const ProfilesReel: React.FC<{lang: Lang}> = ({lang}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = copy[lang];
  const START = 54;
  const SEGP = 50;
  const i = Math.floor((f - START) / SEGP);
  const active = f >= START && i < 3;
  const segStart = START + i * SEGP;
  const kinds: ScreenKind[] = ['slides', 'scroll', 'video'];
  const symbols = ['play.rectangle.fill', 'arrow.up.and.down', 'film'];
  const profiles = ['Presentations', 'Browsing', 'Video'];
  const steps = useSteps([segStart + 20, segStart + 32]);
  const END_TEXT = START + 3 * SEGP; // 204
  const END = END_TEXT + 34; // 238
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <Background />
      {f < START + 2 ? (
        <Top y={SAFE.top + 260}>
          <Kinetic text={t.pHook} at={4} size={96} highlight={['app', 'knows', 'jaanta']} out={START - 8} />
        </Top>
      ) : null}
      {active ? (
        <AbsoluteFill>
          <Top>
            <div style={{display: 'flex', gap: 18}}>
              {t.pApps.map((a, k) => (
                <Chip key={a.app} label={a.app} hot={k === i} appear={1} size={36} />
              ))}
            </div>
          </Top>
          <Center y={20}>
            <MacScreen kind={kinds[i]} steps={steps} appear={spring({frame: f - segStart, fps, config: {damping: 15}})} title={t.pApps[i].app} />
          </Center>
          <div style={{position: 'absolute', left: 0, right: 0, bottom: SAFE.bottom + 40, display: 'flex', justifyContent: 'center'}}>
            <HUD
              key={i}
              symbol={symbols[i]}
              title={`${t.pProfile}: ${profiles[i]}`}
              subtitle={`${t.pApps[i].mode} mode`}
              appear={spring({frame: f - segStart - 6, fps, config: {damping: 14}})}
              scale={2}
            />
          </div>
        </AbsoluteFill>
      ) : null}
      {[0, 1, 2].map((k) => (
        <React.Fragment key={k}>
          <Sfx at={START + k * SEGP} name="whoosh" volume={0.45} />
          <Sfx at={START + k * SEGP + 6} name="pop" volume={0.5} />
          <Sfx at={START + k * SEGP + 20} name="click" volume={0.6} />
          <Sfx at={START + k * SEGP + 32} name="click" volume={0.6} />
        </React.Fragment>
      ))}
      {f >= END_TEXT && f < END + 2 ? (
        <Center>
          <Kinetic text={t.pEnd} at={END_TEXT + 2} size={110} weight={900} highlight={['dial.', 'Every', 'Har']} out={END - 6} />
        </Center>
      ) : null}
      {f >= END ? <EndCard lang={lang} at={END} /> : null}
    </AbsoluteFill>
  );
};

export const DURATIONS = {hero: 640, radial: 316, profiles: 316};
