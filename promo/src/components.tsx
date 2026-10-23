import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, font} from './theme';

export const sym = (name: string) => staticFile(`symbols/${name.replace(/\./g, '-')}.png`);

/** Graphite background with a slow-moving orange glow and faint dial ticks. */
export const Background: React.FC<{glowX?: number; glowY?: number; intensity?: number}> = ({
  glowX = 0.5,
  glowY = 0.45,
  intensity = 1,
}) => {
  const f = useCurrentFrame();
  const drift = Math.sin(f / 60) * 0.03;
  return (
    <AbsoluteFill style={{background: `linear-gradient(180deg, ${C.bg1} 0%, ${C.bg0} 100%)`}}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at ${(glowX + drift) * 100}% ${glowY * 100}%, rgba(255,107,44,${0.32 * intensity}) 0%, rgba(255,107,44,0) 46%)`,
        }}
      />
      <TickRing size={1500} opacity={0.06} rotate={f * 0.08} x={540} y={960} />
      <AbsoluteFill
        style={{
          backgroundImage:
            'radial-gradient(rgba(255,255,255,0.025) 1px, transparent 1px)',
          backgroundSize: '6px 6px',
          mixBlendMode: 'overlay',
        }}
      />
    </AbsoluteFill>
  );
};

export const TickRing: React.FC<{size: number; opacity: number; rotate?: number; x: number; y: number}> = ({
  size,
  opacity,
  rotate = 0,
  x,
  y,
}) => {
  const ticks = Array.from({length: 64});
  return (
    <svg
      width={size}
      height={size}
      style={{position: 'absolute', left: x - size / 2, top: y - size / 2, transform: `rotate(${rotate}deg)`, opacity}}
      viewBox="-100 -100 200 200"
    >
      {ticks.map((_, i) => {
        const a = (i / ticks.length) * Math.PI * 2;
        const long = i % 4 === 0;
        const r1 = long ? 88 : 91;
        return (
          <line
            key={i}
            x1={Math.cos(a) * r1}
            y1={Math.sin(a) * r1}
            x2={Math.cos(a) * 96}
            y2={Math.sin(a) * 96}
            stroke="white"
            strokeWidth={long ? 1.2 : 0.7}
            strokeLinecap="round"
          />
        );
      })}
    </svg>
  );
};

/** Text that rises in word by word with a spring and a blur fade. */
export const Kinetic: React.FC<{
  text: string;
  at: number;
  size?: number;
  weight?: number;
  color?: string;
  stagger?: number;
  align?: 'center' | 'left';
  highlight?: string[];
  out?: number;
}> = ({text, at, size = 92, weight = 800, color = C.text, stagger = 3, align = 'center', highlight = [], out}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const lines = text.split('\n');
  let index = 0;
  const outP = out === undefined ? 0 : interpolate(f, [out, out + 10], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return (
    <div
      style={{
        fontFamily: font,
        fontSize: size,
        fontWeight: weight,
        color,
        lineHeight: 1.08,
        letterSpacing: -size * 0.03,
        textAlign: align,
        opacity: 1 - outP,
        transform: `translateY(${-40 * outP}px)`,
      }}
    >
      {lines.map((line, li) => (
        <div key={li} style={{display: 'flex', flexWrap: 'wrap', justifyContent: align === 'center' ? 'center' : 'flex-start', gap: `0 ${size * 0.26}px`}}>
          {line.split(' ').map((word, wi) => {
            const i = index++;
            const p = spring({frame: f - at - i * stagger, fps, config: {damping: 14, mass: 0.7}});
            const hot = highlight.some((h) => word.toLowerCase().includes(h.toLowerCase()));
            return (
              <span
                key={wi}
                style={{
                  display: 'inline-block',
                  transform: `translateY(${(1 - p) * size * 0.7}px) scale(${0.9 + 0.1 * p})`,
                  opacity: p,
                  filter: `blur(${(1 - p) * 12}px)`,
                  color: hot ? C.accent : undefined,
                }}
              >
                {word}
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
};

/** A stylised CMF Buds Pro 2 case with its Smart Dial. `rotation` in degrees. */
export const CaseDial: React.FC<{rotation: number; pulse?: number; scale?: number}> = ({rotation, pulse = 0, scale = 1}) => {
  const ringOpacity = interpolate(pulse, [0, 1], [0, 0.6]);
  const ringScale = interpolate(pulse, [0, 1], [1, 1.35]);
  return (
    <div style={{position: 'relative', width: 620 * scale, height: 520 * scale}}>
      {/* Case body */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: 150 * scale,
          background: 'linear-gradient(160deg, #3A3A3F 0%, #1C1C20 55%, #121215 100%)',
          boxShadow: '0 40px 80px rgba(0,0,0,0.55), inset 0 2px 0 rgba(255,255,255,0.12), inset 0 -6px 20px rgba(0,0,0,0.5)',
        }}
      />
      {/* Lid seam */}
      <div
        style={{
          position: 'absolute',
          left: 40 * scale,
          right: 40 * scale,
          top: 190 * scale,
          height: 3 * scale,
          borderRadius: 2,
          background: 'rgba(0,0,0,0.55)',
          boxShadow: '0 1px 0 rgba(255,255,255,0.06)',
        }}
      />
      {/* Click pulse */}
      <div
        style={{
          position: 'absolute',
          right: 70 * scale,
          bottom: 70 * scale,
          width: 220 * scale,
          height: 220 * scale,
          borderRadius: '50%',
          border: `${4 * scale}px solid ${C.accent}`,
          opacity: ringOpacity * (1 - pulse),
          transform: `scale(${ringScale})`,
        }}
      />
      {/* Dial */}
      <div
        style={{
          position: 'absolute',
          right: 70 * scale,
          bottom: 70 * scale,
          width: 220 * scale,
          height: 220 * scale,
          borderRadius: '50%',
          background: `conic-gradient(from 0deg, #FF8A4C, ${C.accent}, #D9531C, #FF8A4C, ${C.accent}, #D9531C, #FF8A4C)`,
          boxShadow: `0 12px 30px rgba(255,107,44,0.35), inset 0 3px 0 rgba(255,255,255,0.35), inset 0 -8px 16px rgba(0,0,0,0.35)`,
          transform: `rotate(${rotation}deg)`,
        }}
      >
        {/* Knurled edge */}
        <svg viewBox="-100 -100 200 200" style={{position: 'absolute', inset: 0}}>
          {Array.from({length: 48}).map((_, i) => {
            const a = (i / 48) * Math.PI * 2;
            return (
              <line key={i} x1={Math.cos(a) * 88} y1={Math.sin(a) * 88} x2={Math.cos(a) * 98} y2={Math.sin(a) * 98} stroke="rgba(0,0,0,0.28)" strokeWidth={2} />
            );
          })}
          <circle r={64} fill="rgba(0,0,0,0.12)" />
          <circle cx={0} cy={-48} r={9} fill="white" opacity={0.9} />
        </svg>
      </div>
    </div>
  );
};

/** Dialed's radial menu, recreated. `highlight` may be fractional for smooth glides. */
export const RadialMenu: React.FC<{
  items: {symbol: string; label: string; hint?: string}[];
  highlight: number;
  appear: number;
  current?: number;
  chosen?: number;
  size?: number;
}> = ({items, highlight, appear, current = 0, chosen = 0, size = 860}) => {
  const n = items.length;
  const ring = size * 0.38;
  const item = size * 0.15;
  const inner = ring - item / 2 - size * 0.045;
  const active = ((Math.round(highlight) % n) + n) % n;
  const seg = 360 / n;
  return (
    <div
      style={{
        position: 'relative',
        width: size,
        height: size,
        transform: `scale(${0.82 + 0.18 * appear})`,
        opacity: appear,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background: 'radial-gradient(circle at 50% 40%, #232227 0%, #141417 100%)',
          border: `1.5px solid ${C.stroke}`,
          boxShadow: '0 50px 120px rgba(0,0,0,0.6)',
        }}
      />
      {/* Inner track and indicator arc */}
      <svg width={size} height={size} style={{position: 'absolute', inset: 0}}>
        <circle cx={size / 2} cy={size / 2} r={inner} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={8} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={inner}
          fill="none"
          stroke={C.accent}
          strokeWidth={8}
          strokeLinecap="round"
          strokeDasharray={`${(2 * Math.PI * inner * 0.7) / n} ${2 * Math.PI * inner}`}
          transform={`rotate(${-90 + seg * (highlight - 0.35)} ${size / 2} ${size / 2})`}
          style={{filter: `drop-shadow(0 0 10px ${C.accent})`}}
        />
      </svg>
      {items.map((it, i) => {
        const a = (i / n) * Math.PI * 2 - Math.PI / 2;
        const d = Math.min(Math.abs(i - (((highlight % n) + n) % n)), n - Math.abs(i - (((highlight % n) + n) % n)));
        const hot = Math.max(0, 1 - d);
        const pop = chosen > 0 && i === active ? 1 + 0.15 * chosen : 1;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: size / 2 + Math.cos(a) * ring - item / 2,
              top: size / 2 + Math.sin(a) * ring - item / 2,
              width: item,
              height: item,
              borderRadius: '50%',
              background: hot > 0.5 ? `linear-gradient(160deg, #FF8A4C, ${C.accent})` : 'rgba(255,255,255,0.09)',
              boxShadow: hot > 0.5 ? `0 0 ${30 * hot}px rgba(255,107,44,0.7)` : 'none',
              border: i === current && hot < 0.5 ? `3px solid rgba(255,107,44,0.85)` : 'none',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transform: `scale(${(1 + 0.14 * hot) * pop})`,
            }}
          >
            <Img src={sym(it.symbol)} style={{width: item * 0.46, height: item * 0.46, opacity: hot > 0.5 ? 1 : 0.8}} />
          </div>
        );
      })}
      <div
        style={{
          position: 'absolute',
          left: size / 2 - size * 0.2,
          top: size / 2 - size * 0.09,
          width: size * 0.4,
          textAlign: 'center',
          fontFamily: font,
          color: 'white',
        }}
      >
        <div style={{fontSize: size * 0.05, fontWeight: 700}}>{items[active].label}</div>
        {items[active].hint ? (
          <div style={{fontSize: size * 0.025, fontWeight: 500, color: C.dim, marginTop: 10}}>{items[active].hint}</div>
        ) : null}
      </div>
    </div>
  );
};

/** The on-screen feedback capsule. */
export const HUD: React.FC<{symbol: string; title: string; subtitle?: string; level?: number; appear: number; scale?: number}> = ({
  symbol,
  title,
  subtitle,
  level,
  appear,
  scale = 1.6,
}) => (
  <div
    style={{
      display: 'flex',
      alignItems: 'center',
      gap: 14 * scale,
      padding: `${10 * scale}px ${22 * scale}px ${10 * scale}px ${12 * scale}px`,
      borderRadius: 999,
      background: 'rgba(32,32,36,0.92)',
      border: `1px solid ${C.stroke}`,
      boxShadow: '0 20px 50px rgba(0,0,0,0.5)',
      fontFamily: font,
      opacity: appear,
      transform: `translateY(${(1 - appear) * 30}px) scale(${0.92 + 0.08 * appear})`,
    }}
  >
    <div
      style={{
        width: 38 * scale,
        height: 38 * scale,
        borderRadius: '50%',
        background: `linear-gradient(160deg, #FF8A4C, ${C.accent})`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Img src={sym(symbol)} style={{width: 20 * scale, height: 20 * scale}} />
    </div>
    <div style={{minWidth: 170 * scale}}>
      <div style={{color: 'white', fontWeight: 700, fontSize: 15 * scale}}>{title}</div>
      {level !== undefined ? (
        <div style={{marginTop: 6 * scale, height: 6 * scale, borderRadius: 99, background: 'rgba(255,255,255,0.15)', width: 180 * scale}}>
          <div style={{height: '100%', width: `${Math.max(4, level * 100)}%`, borderRadius: 99, background: C.accent}} />
        </div>
      ) : null}
      {subtitle ? <div style={{color: C.dim, fontSize: 12.5 * scale, marginTop: 3 * scale}}>{subtitle}</div> : null}
    </div>
  </div>
);

/** Pill with an icon and a label. */
export const Chip: React.FC<{symbol?: string; label: string; appear: number; hot?: boolean; size?: number}> = ({
  symbol,
  label,
  appear,
  hot,
  size = 38,
}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: size * 0.4,
      padding: `${size * 0.35}px ${size * 0.7}px`,
      borderRadius: 999,
      background: hot ? `linear-gradient(160deg, #FF8A4C, ${C.accent})` : 'rgba(255,255,255,0.07)',
      border: hot ? 'none' : `1.5px solid ${C.stroke}`,
      fontFamily: font,
      fontWeight: 700,
      fontSize: size,
      color: 'white',
      opacity: appear,
      transform: `translateY(${(1 - appear) * 24}px) scale(${0.9 + 0.1 * appear})`,
      boxShadow: hot ? '0 10px 30px rgba(255,107,44,0.35)' : 'none',
    }}
  >
    {symbol ? <Img src={sym(symbol)} style={{width: size * 1.05, height: size * 1.05}} /> : null}
    {label}
  </div>
);

export const AppIcon: React.FC<{size: number; style?: React.CSSProperties}> = ({size, style}) => (
  <Img src={staticFile('icon.png')} style={{width: size, height: size, filter: 'drop-shadow(0 30px 60px rgba(0,0,0,0.55))', ...style}} />
);
