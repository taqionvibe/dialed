import React from 'react';
import {Img, interpolate} from 'remotion';
import {sym} from './components';
import {C, font} from './theme';

export type ScreenKind = 'scroll' | 'slides' | 'video' | 'brightness' | 'volume';

/**
 * A Mac window showing what the dial does. `steps` is a smooth, possibly
 * fractional click count (sum of springs), so content moves click by click.
 */
export const MacScreen: React.FC<{kind: ScreenKind; steps: number; appear: number; title?: string; width?: number}> = ({
  kind,
  steps,
  appear,
  title,
  width = 920,
}) => {
  const height = width * 0.66;
  return (
    <div
      style={{
        width,
        height,
        borderRadius: 26,
        overflow: 'hidden',
        background: '#1A1A1E',
        border: `1.5px solid ${C.stroke}`,
        boxShadow: '0 50px 110px rgba(0,0,0,0.6)',
        opacity: appear,
        transform: `translateY(${(1 - appear) * 60}px) scale(${0.94 + 0.06 * appear})`,
        position: 'relative',
        fontFamily: font,
      }}
    >
      <div style={{height: 54, display: 'flex', alignItems: 'center', gap: 12, padding: '0 22px', background: '#232227', borderBottom: `1px solid ${C.stroke}`}}>
        {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => (
          <div key={c} style={{width: 15, height: 15, borderRadius: '50%', background: c}} />
        ))}
        <div style={{flex: 1, textAlign: 'center', color: C.dim, fontSize: 20, fontWeight: 600, marginRight: 70}}>{title ?? defaultTitle[kind]}</div>
      </div>
      <div style={{position: 'absolute', top: 54, left: 0, right: 0, bottom: 0, overflow: 'hidden'}}>{content(kind, steps, width, height - 54)}</div>
    </div>
  );
};

const defaultTitle: Record<ScreenKind, string> = {
  scroll: 'Safari',
  slides: 'Keynote',
  video: 'QuickTime Player',
  brightness: 'Display',
  volume: 'Music',
};

export function content(kind: ScreenKind, steps: number, w: number, h: number) {
  switch (kind) {
    case 'scroll':
      return <Article offset={steps * 170} w={w} />;
    case 'slides':
      return <Slides index={steps} w={w} h={h} />;
    case 'video':
      return <Video t={steps} w={w} h={h} />;
    case 'brightness':
      return <Brightness level={1 - steps * 0.22} w={w} h={h} />;
    case 'volume':
      return <Volume level={0.35 + steps * 0.15} w={w} h={h} />;
  }
}

const Bar: React.FC<{w: number | string; h?: number; o?: number; c?: string}> = ({w, h = 14, o = 0.14, c = 'white'}) => (
  <div style={{width: w, height: h, borderRadius: 8, background: c, opacity: o, marginBottom: 14}} />
);

const Article: React.FC<{offset: number; w: number}> = ({offset, w}) => (
  <div style={{padding: '40px 70px', transform: `translateY(${-offset}px)`}}>
    <Bar w="62%" h={34} o={0.85} />
    <Bar w="40%" h={18} o={0.3} />
    <div style={{height: 26}} />
    {Array.from({length: 7}).map((_, i) => (
      <React.Fragment key={i}>
        {i % 3 === 1 ? (
          <div
            style={{
              height: 200,
              borderRadius: 18,
              marginBottom: 26,
              background: [
                'linear-gradient(135deg,#FF8A4C,#7A2E8E)',
                'linear-gradient(135deg,#2E7DFF,#16C2A3)',
                'linear-gradient(135deg,#F5C542,#FF6B2C)',
              ][i % 3],
              opacity: 0.85,
            }}
          />
        ) : null}
        <Bar w="100%" />
        <Bar w="96%" />
        <Bar w="88%" />
        <Bar w="72%" />
        <div style={{height: 18}} />
      </React.Fragment>
    ))}
  </div>
);

const Slides: React.FC<{index: number; w: number; h: number}> = ({index, w, h}) => {
  const slides = [
    {t: 'Q4 Results', c: 'linear-gradient(135deg,#1F1F24,#3A2A22)'},
    {t: '+42% growth', c: 'linear-gradient(135deg,#FF6B2C,#B23A0E)'},
    {t: 'Next steps', c: 'linear-gradient(135deg,#2E7DFF,#173C8A)'},
    {t: 'Thank you', c: 'linear-gradient(135deg,#16C2A3,#0D5E52)'},
  ];
  return (
    <div style={{display: 'flex', height: '100%', transform: `translateX(${-index * w}px)`}}>
      {slides.map((s, i) => (
        <div key={i} style={{minWidth: w, height: h, padding: 50, boxSizing: 'border-box'}}>
          <div style={{width: '100%', height: '100%', borderRadius: 18, background: s.c, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
            <div style={{color: 'white', fontSize: 72, fontWeight: 800, letterSpacing: -2}}>{s.t}</div>
          </div>
        </div>
      ))}
    </div>
  );
};

const Video: React.FC<{t: number; w: number; h: number}> = ({t, w, h}) => {
  const p = Math.min(0.92, 0.12 + t * 0.18);
  return (
    <div style={{width: '100%', height: '100%', background: '#000', position: 'relative'}}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(circle at ${30 + p * 50}% 40%, rgba(255,140,60,0.75), rgba(30,40,90,0.9) 55%, #05060A 100%)`,
        }}
      />
      <div style={{position: 'absolute', left: 40, right: 40, bottom: 40}}>
        <div style={{display: 'flex', justifyContent: 'space-between', color: 'white', fontSize: 22, fontWeight: 600, marginBottom: 12, opacity: 0.85}}>
          <span>{formatTime(p * 312)}</span>
          <span>5:12</span>
        </div>
        <div style={{height: 10, borderRadius: 10, background: 'rgba(255,255,255,0.25)'}}>
          <div style={{width: `${p * 100}%`, height: '100%', borderRadius: 10, background: C.accent, position: 'relative'}}>
            <div style={{position: 'absolute', right: -12, top: -9, width: 28, height: 28, borderRadius: '50%', background: 'white'}} />
          </div>
        </div>
      </div>
    </div>
  );
};

function formatTime(s: number) {
  const m = Math.floor(s / 60);
  const r = Math.floor(s % 60);
  return `${m}:${r.toString().padStart(2, '0')}`;
}

const Brightness: React.FC<{level: number; w: number; h: number}> = ({level, w, h}) => (
  <div style={{width: '100%', height: '100%', position: 'relative', background: 'linear-gradient(160deg,#FFB36B 0%,#FF6B2C 40%,#7A2E8E 100%)'}}>
    <div style={{position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
      <Img src={sym('sun.max.fill')} style={{width: 200, height: 200, opacity: 0.9}} />
    </div>
    <div style={{position: 'absolute', inset: 0, background: 'black', opacity: interpolate(level, [0.2, 1], [0.72, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}} />
  </div>
);

const Volume: React.FC<{level: number; w: number; h: number}> = ({level, w, h}) => {
  const bars = 28;
  return (
    <div style={{width: '100%', height: '100%', background: 'linear-gradient(160deg,#241A2E,#101014)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12}}>
      {Array.from({length: bars}).map((_, i) => {
        const v = 0.25 + 0.75 * Math.abs(Math.sin(i * 1.7 + level * 9));
        return (
          <div key={i} style={{width: 14, height: `${Math.min(80, v * level * 100)}%`, borderRadius: 8, background: i / bars < level ? C.accent : 'rgba(255,255,255,0.18)'}} />
        );
      })}
    </div>
  );
};
