import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {CaseColor, CaseModel} from './CaseModel';
import {content, ScreenKind} from './MacScreen';
import {C, font} from './theme';

// ───────────── The case (3D model drawn from CMF's product photos) ─────────────

/** Case seen from above at a slight lean, dial on the right; the dial turns by `rotation`. */
export const RealCaseTop: React.FC<{width: number; rotation: number; clicks?: number[]; glow?: number; tilt?: number; color?: CaseColor}> = ({
  width,
  rotation,
  clicks = [],
  glow = 1,
  tilt = 30,
  color,
}) => {
  const S = width * 0.7;
  return (
    <div style={{width, height: width * 0.92, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
      <div style={{transform: `translateX(${-width * 0.04}px)`}}>
        <CaseModel size={S} dial={rotation} clicks={clicks} glow={glow} tiltX={tilt} angle={45} color={color} />
      </div>
    </div>
  );
};

/** Low side view that shows the knurled dial edge; `tiltY` spins it like a turntable. */
export const RealCaseSide: React.FC<{width: number; tiltY?: number; tiltX?: number; dial?: number}> = ({width, tiltY = 0, tiltX = 0, dial = 0}) => {
  const S = width * 0.6;
  return (
    <div style={{width, height: width * 0.7, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
      <CaseModel size={S} dial={dial} tiltX={60 + tiltX * 0.5} angle={45 + tiltY} glow={0.6} />
    </div>
  );
};

/** Orange sparks bursting from a point for ~14 frames after `at`. */
export const Sparks: React.FC<{at: number; x: number; y: number; radius: number; count?: number}> = ({at, x, y, radius, count = 14}) => {
  const f = useCurrentFrame();
  const t = f - at;
  if (t < 0 || t > 16) return null;
  const p = t / 16;
  return (
    <>
      {Array.from({length: count}).map((_, i) => {
        const a = (i / count) * Math.PI * 2 + at * 0.37;
        const dist = radius * (1.05 + 0.9 * Math.pow(p, 0.6)) * (0.8 + ((i * 37) % 10) / 25);
        const size = 9 * (1 - p) + 2;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x + Math.cos(a) * dist - size / 2,
              top: y + Math.sin(a) * dist - size / 2,
              width: size,
              height: size,
              borderRadius: '50%',
              background: i % 3 === 0 ? '#FFD2B8' : C.accent,
              opacity: 1 - p,
              boxShadow: `0 0 12px ${C.accent}`,
            }}
          />
        );
      })}
    </>
  );
};

/** Expanding ring (click / shockwave). */
export const Ring: React.FC<{at: number; x: number; y: number; size: number; length?: number; color?: string; width?: number}> = ({
  at,
  x,
  y,
  size,
  length = 14,
  color = C.accent,
  width = 6,
}) => {
  const f = useCurrentFrame();
  const t = f - at;
  if (t < 0 || t > length) return null;
  const p = t / length;
  const s = 1 + p * 0.9;
  return (
    <div
      style={{
        position: 'absolute',
        left: x - (size * s) / 2,
        top: y - (size * s) / 2,
        width: size * s,
        height: size * s,
        borderRadius: '50%',
        border: `${width * (1 - p) + 1}px solid ${color}`,
        opacity: 1 - p,
      }}
    />
  );
};

// ───────────── Camera, flashes, text ─────────────

/** Scene camera: slow push-in plus a scale "punch" on each beat. */
export const Camera: React.FC<{children: React.ReactNode; beats?: number[]; push?: number; shake?: number; from?: number}> = ({
  children,
  beats = [],
  push = 0.05,
  shake = 0,
  from = 0,
}) => {
  const f = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const base = 1 + push * interpolate(f, [from, durationInFrames], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const punch = beats.reduce((acc, b) => {
    const t = f - b;
    return t >= 0 && t < 8 ? acc + 0.035 * Math.exp(-t / 2.5) : acc;
  }, 0);
  const sx = shake ? Math.sin(f * 2.3) * shake : 0;
  const sy = shake ? Math.cos(f * 1.7) * shake : 0;
  return <AbsoluteFill style={{transform: `translate(${sx}px, ${sy}px) scale(${base + punch})`}}>{children}</AbsoluteFill>;
};

export const Flash: React.FC<{at: number; length?: number; color?: string}> = ({at, length = 10, color = 'white'}) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [at, at + 1, at + length], [0, 0.9, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return <AbsoluteFill style={{background: color, opacity: o, pointerEvents: 'none'}} />;
};

/** Big headline that slams in (scale down from 1.6, blur → sharp), optional exit. */
export const Slam: React.FC<{
  text: string;
  at: number;
  size?: number;
  color?: string;
  out?: number;
  hot?: string[];
  weight?: number;
  align?: 'center' | 'left';
}> = ({text, at, size = 110, color = 'white', out, hot = [], weight = 900, align = 'center'}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = spring({frame: f - at, fps, config: {damping: 11, mass: 0.55, stiffness: 180}});
  const o = out === undefined ? 1 : interpolate(f, [out, out + 6], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const scale = 1.6 - 0.6 * p;
  return (
    <div
      style={{
        fontFamily: font,
        fontWeight: weight,
        fontSize: size,
        lineHeight: 1.02,
        letterSpacing: -size * 0.035,
        color,
        textAlign: align,
        whiteSpace: 'pre-line',
        opacity: Math.min(1, p * 1.5) * o,
        transform: `scale(${scale}) translateY(${(1 - o) * -30}px)`,
        filter: `blur(${(1 - p) * 16}px)`,
        textShadow: '0 10px 40px rgba(0,0,0,0.6)',
      }}
    >
      {text.split(/(\s+)/).map((w, i) => (
        <span key={i} style={{color: hot.some((h) => w.toLowerCase().includes(h.toLowerCase())) ? C.accent : undefined}}>
          {w}
        </span>
      ))}
    </div>
  );
};

/** Small caps label above a headline. */
export const Eyebrow: React.FC<{text: string; at: number; out?: number}> = ({text, at, out}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = spring({frame: f - at, fps, config: {damping: 14}});
  const o = out === undefined ? 1 : interpolate(f, [out, out + 6], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 14,
        padding: '14px 28px',
        borderRadius: 999,
        background: 'rgba(255,107,44,0.14)',
        border: '1.5px solid rgba(255,107,44,0.5)',
        color: '#FFB48F',
        fontFamily: font,
        fontWeight: 800,
        fontSize: 34,
        letterSpacing: 1,
        textTransform: 'uppercase',
        opacity: p * o,
        transform: `translateY(${(1 - p) * 20}px)`,
      }}
    >
      {text}
    </div>
  );
};

/** Whip transition: content flies in from the right with motion blur, out to the left. */
export const Whip: React.FC<{children: React.ReactNode; inAt: number; outAt: number}> = ({children, inAt, outAt}) => {
  const f = useCurrentFrame();
  const inP = interpolate(f, [inAt, inAt + 7], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const outP = interpolate(f, [outAt - 6, outAt], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const ease = (x: number) => x * x * (3 - 2 * x);
  const x = 1100 * ease(inP) - 1100 * ease(outP);
  const blur = 26 * Math.max(inP, outP) * (1 - Math.max(inP, outP) * 0.4);
  return (
    <AbsoluteFill style={{transform: `translateX(${x}px) skewX(${(inP - outP) * -8}deg)`, filter: `blur(${blur}px)`}}>{children}</AbsoluteFill>
  );
};

// ───────────── MacBook mock ─────────────

export const MacBook: React.FC<{kind: ScreenKind; steps: number; width?: number; title?: string}> = ({kind, steps, width = 940}) => {
  const screenW = width * 0.9;
  const screenH = screenW * 0.63;
  return (
    <div style={{width, display: 'flex', flexDirection: 'column', alignItems: 'center', filter: 'drop-shadow(0 50px 70px rgba(0,0,0,0.6))'}}>
      <div
        style={{
          width: screenW + 26,
          padding: 13,
          borderRadius: 28,
          background: 'linear-gradient(180deg,#2A2A2E,#151517)',
          border: '1.5px solid rgba(255,255,255,0.12)',
          position: 'relative',
        }}
      >
        <div style={{position: 'absolute', top: 13, left: '50%', width: 120, height: 18, marginLeft: -60, background: '#000', borderRadius: '0 0 10px 10px', zIndex: 2}} />
        <div style={{width: screenW, height: screenH, borderRadius: 14, overflow: 'hidden', background: '#000', position: 'relative'}}>
          <div style={{position: 'absolute', inset: 0}}>{content(kind, steps, screenW, screenH)}</div>
        </div>
      </div>
      <div style={{width: width, height: 26, marginTop: -2, borderRadius: '0 0 24px 24px', background: 'linear-gradient(180deg,#C9C9CE,#8E8E94)'}} />
      <div style={{width: width * 0.16, height: 8, marginTop: -26, borderRadius: '0 0 10px 10px', background: 'rgba(0,0,0,0.25)'}} />
    </div>
  );
};

/** Grid of beat frames: `count` beats from `start`, `step` frames apart. */
export const beatGrid = (start: number, count: number, step: number) =>
  Array.from({length: count}, (_, i) => Math.round(start + i * step));

export const useSpringAt = (at: number, damping = 14) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({frame: f - at, fps, config: {damping}});
};
