import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, useCurrentFrame} from 'remotion';
import {sym} from './components';
import {C, font} from './theme';

const norm = (x: string) => x.toLowerCase().replace(/[^\p{L}\p{N}-]/gu, '');
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const sp = (f: number, at: number, config: {damping?: number; stiffness?: number; mass?: number} = {}) =>
  spring({frame: f - at, fps: 30, config: {damping: 11, stiffness: 190, mass: 0.6, ...config}});

/**
 * Kinetic headline: each word bounces up into place one after another, hot words get
 * an orange marker that swipes in behind them, and on `out` the words fly away upward.
 */
export const Words: React.FC<{
  text: string;
  at: number;
  size?: number;
  hot?: string[];
  out?: number;
  stagger?: number;
  color?: string;
}> = ({text, at, size = 96, hot = [], out, stagger = 3, color = 'white'}) => {
  const f = useCurrentFrame();
  let idx = 0;
  return (
    <div style={{fontFamily: font, fontWeight: 900, fontSize: size, lineHeight: 1.08, letterSpacing: -size * 0.035, color, textAlign: 'center'}}>
      {text.split('\n').map((line, li) => (
        <div key={li} style={{whiteSpace: 'nowrap'}}>
          {line.split(' ').map((w, wi) => {
            const i = idx++;
            const start = at + i * stagger;
            const p = sp(f, start);
            const q = out === undefined ? 0 : interpolate(f, [out + i * 1.5, out + i * 1.5 + 8], [0, 1], clamp);
            const isHot = hot.some((h) => norm(w) === norm(h));
            const mark = sp(f, start + 6, {damping: 18});
            return (
              <span
                key={wi}
                style={{
                  display: 'inline-block',
                  position: 'relative',
                  margin: `0 ${size * 0.1}px`,
                  transform: `translateY(${(1 - p) * size * 0.8 - q * size * 0.7}px) rotate(${(1 - p) * (i % 2 ? 9 : -9)}deg) scale(${0.55 + 0.45 * p})`,
                  opacity: Math.min(1, p * 2) * (1 - q),
                  filter: `blur(${(1 - Math.min(1, p)) * 8 + q * 10}px)`,
                }}
              >
                {isHot ? (
                  <span
                    style={{
                      position: 'absolute',
                      left: -size * 0.1,
                      right: -size * 0.1,
                      top: size * 0.12,
                      bottom: size * 0.02,
                      background: C.accent,
                      borderRadius: size * 0.14,
                      transform: `scaleX(${mark}) rotate(-1.5deg)`,
                      transformOrigin: 'left center',
                      boxShadow: `0 8px 30px rgba(255,107,44,0.45)`,
                    }}
                  />
                ) : null}
                <span style={{position: 'relative', textShadow: isHot ? undefined : '0 10px 40px rgba(0,0,0,0.6)'}}>{w}</span>
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
};

/** Supporting line under a headline: smaller, softer, words fade up one by one. */
export const Sub: React.FC<{text: string; at: number; out?: number; size?: number}> = ({text, at, out, size = 42}) => {
  const f = useCurrentFrame();
  const q = out === undefined ? 0 : interpolate(f, [out, out + 6], [0, 1], clamp);
  return (
    <div style={{fontFamily: font, fontWeight: 600, fontSize: size, lineHeight: 1.3, color: 'rgba(255,255,255,0.78)', textAlign: 'center', opacity: 1 - q, maxWidth: 900}}>
      {text.split(' ').map((w, i) => {
        const p = sp(f, at + i * 1.6, {damping: 16});
        return (
          <span key={i} style={{display: 'inline-block', marginRight: size * 0.26, opacity: p, transform: `translateY(${(1 - p) * 24}px)`}}>
            {w}
          </span>
        );
      })}
    </div>
  );
};

/** Drifting embers behind everything; they flare a little on each beat. */
export const Particles: React.FC<{beats?: number[]; count?: number; intensity?: number}> = ({beats = [], count = 38, intensity = 1}) => {
  const f = useCurrentFrame();
  const flare = beats.reduce((a, b) => (f >= b && f < b + 10 ? Math.max(a, 1 - (f - b) / 10) : a), 0);
  return (
    <AbsoluteFill style={{pointerEvents: 'none'}}>
      {Array.from({length: count}).map((_, i) => {
        const rx = ((i * 137.508) % 100) / 100;
        const ry = ((i * 61.803 + 17) % 100) / 100;
        const speed = 0.6 + ((i * 7) % 10) / 8;
        const y = ((ry * 2100 - f * speed * 2.2) % 2100 + 2100) % 2100 - 90;
        const x = rx * 1080 + Math.sin(f / 30 + i) * 22;
        const s = 3 + ((i * 13) % 7);
        const tw = 0.25 + 0.35 * (0.5 + 0.5 * Math.sin(f / 9 + i * 2.1));
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              width: s,
              height: s,
              borderRadius: '50%',
              background: i % 4 === 0 ? '#FFFFFF' : C.accent,
              opacity: Math.min(1, (tw + flare * 0.5) * intensity),
              boxShadow: `0 0 ${s * 3}px ${C.accent}`,
              transform: `scale(${1 + flare * 0.8})`,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

/** Light rays bursting from a point (used on the drop). */
export const Rays: React.FC<{at: number; x?: number; y?: number; length?: number}> = ({at, x = 540, y = 900, length = 40}) => {
  const f = useCurrentFrame();
  const t = f - at;
  if (t < 0 || t > length) return null;
  const p = t / length;
  const o = interpolate(t, [0, 3, length], [0, 0.9, 0], clamp);
  return (
    <div
      style={{
        position: 'absolute',
        left: x - 1400,
        top: y - 1400,
        width: 2800,
        height: 2800,
        borderRadius: '50%',
        background: `repeating-conic-gradient(from ${t * 1.5}deg, rgba(255,140,80,0.55) 0deg 4deg, rgba(255,140,80,0) 4deg 15deg)`,
        WebkitMaskImage: 'radial-gradient(circle, black 0%, black 18%, transparent 62%)',
        opacity: o,
        transform: `scale(${0.5 + p * 0.9})`,
        mixBlendMode: 'screen',
      }}
    />
  );
};

/** Gentle idle float: bob and sway. */
export const Float: React.FC<{children: React.ReactNode; amp?: number; phase?: number}> = ({children, amp = 12, phase = 0}) => {
  const f = useCurrentFrame();
  return <div style={{transform: `translateY(${Math.sin(f / 14 + phase) * amp}px) rotate(${Math.sin(f / 23 + phase) * 1.6}deg)`}}>{children}</div>;
};

/** A little label that pops out ("boop") and floats up on each click. */
export const ClickPops: React.FC<{clicks: number[]; label?: string; labels?: string[]; symbol?: string; x?: number; y?: number}> = ({clicks, label = '', labels, symbol, x = 0, y = 0}) => {
  const f = useCurrentFrame();
  return (
    <div style={{position: 'absolute', left: x, top: y, width: 0, height: 0}}>
      {clicks.map((c, i) => {
        const t = f - c;
        if (t < 0 || t > 26) return null;
        const p = sp(f, c, {damping: 8, stiffness: 260, mass: 0.5});
        const rise = interpolate(t, [0, 26], [0, -170], clamp);
        const o = interpolate(t, [0, 2, 16, 26], [0, 1, 1, 0], clamp);
        const dx = (i % 2 ? 1 : -1) * 70 + i * 10;
        return (
          <div
            key={c}
            style={{
              position: 'absolute',
              left: dx,
              top: rise,
              transform: `translate(-50%, -50%) scale(${p}) rotate(${(i % 2 ? 1 : -1) * 6 * (1 - p)}deg)`,
              opacity: o,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '12px 22px',
              borderRadius: 999,
              background: C.accent,
              color: 'white',
              fontFamily: font,
              fontWeight: 800,
              fontSize: 34,
              whiteSpace: 'nowrap',
              boxShadow: '0 12px 40px rgba(255,107,44,0.5)',
            }}
          >
            {symbol ? <Img src={sym(symbol)} style={{width: 34, height: 34}} /> : null}
            {labels?.[i] ?? label}
          </div>
        );
      })}
    </div>
  );
};

/** Content that flips up into place in 3D (for the MacBook and cards). */
export const FlipIn: React.FC<{at: number; children: React.ReactNode; from?: 'bottom' | 'left' | 'right'}> = ({at, children, from = 'bottom'}) => {
  const f = useCurrentFrame();
  const p = sp(f, at, {damping: 13, stiffness: 150});
  const r = (1 - p) * 55;
  const tr =
    from === 'bottom'
      ? `translateY(${(1 - p) * 260}px) rotateX(${r}deg)`
      : `translateX(${(from === 'left' ? -1 : 1) * (1 - p) * 500}px) rotateY(${(from === 'left' ? -1 : 1) * r}deg)`;
  return <div style={{perspective: 1600}}><div style={{transform: tr, opacity: Math.min(1, p * 1.6)}}>{children}</div></div>;
};

/** Number that counts up. */
export const Counter: React.FC<{at: number; to: number; duration?: number; size?: number; suffix?: string}> = ({at, to, duration = 18, size = 260, suffix = ''}) => {
  const f = useCurrentFrame();
  const v = Math.round(interpolate(f, [at, at + duration], [0, to], {...clamp, easing: (x) => 1 - Math.pow(1 - x, 3)}));
  const p = sp(f, at, {damping: 9});
  return (
    <div style={{fontFamily: font, fontWeight: 900, fontSize: size, lineHeight: 1, color: C.accent, letterSpacing: -size * 0.04, transform: `scale(${0.6 + 0.4 * p})`, textShadow: '0 20px 80px rgba(255,107,44,0.5)'}}>
      {v}
      {suffix}
    </div>
  );
};
