import React from 'react';
import {useCurrentFrame} from 'remotion';
import {Sparks} from './motion';
import {C} from './theme';

/**
 * A 3D model of the CMF Buds Pro 2 case, drawn from CMF's product photos:
 * a light-grey squircle slab with a brushed-aluminium Smart Dial overhanging one
 * corner, and the LED ring, speaker dots and pairing button on the opposite side.
 * Built from stacked CSS layers, so it can be tilted and spun in real 3D.
 *
 * All lengths are relative to S, the side of the case.
 */
const PALETTES = {
  light: {top: ['#F1F1F3', '#D9D9DC'], side: ['#D4D4D8', '#A9A9AE'], mark: '#B9B9BE'},
  dark: {top: ['#4A4A4F', '#2C2C30'], side: ['#36363A', '#1C1C1F'], mark: '#5E5E64'},
  orange: {top: ['#FF7A45', '#E8501A'], side: ['#F05A22', '#B83A0C'], mark: '#C94716'},
};
export type CaseColor = keyof typeof PALETTES;

const R = 0.22; // corner radius
const DEPTH = 0.44; // case thickness
const DIAL = {x: 0.86, y: 0.14, r: 0.235, rise: 0.055}; // dial centre, radius, height above the lid

export const CaseModel: React.FC<{
  size: number; // side of the case in px
  dial: number; // dial rotation in degrees
  angle?: number; // in-plane rotation of the case (45 = diamond, dial on the right)
  tiltX?: number; // how far it leans back (0 = facing the camera)
  spinY?: number;
  color?: CaseColor;
  clicks?: number[];
  glow?: number;
}> = ({size: S, dial, angle = 45, tiltX = 30, spinY = 0, color = 'light', clicks = [], glow = 0}) => {
  const f = useCurrentFrame();
  const p = PALETTES[color];
  const layers = 56;
  const depth = DEPTH * S;
  const step = depth / layers;
  const lightDir = 180 - angle; // keeps the light coming from the top of the screen
  const dx = DIAL.x * S;
  const dy = DIAL.y * S;
  const dr = DIAL.r * S;
  const rise = DIAL.rise * S;
  const dialLayers = 18;
  const pulse = clicks.reduce((a, c) => {
    const t = f - c;
    return t >= 0 && t < 10 ? Math.max(a, 1 - t / 10) : a;
  }, 0);

  const abs: React.CSSProperties = {position: 'absolute', left: 0, top: 0};
  return (
    <div style={{width: S, height: S, perspective: S * 4.2, position: 'relative'}}>
      {/* soft floor shadow */}
      <div
        style={{
          ...abs,
          left: -S * 0.1,
          top: S * 0.25,
          width: S * 1.3,
          height: S * 1.0,
          borderRadius: '50%',
          background: 'radial-gradient(closest-side, rgba(0,0,0,0.55), rgba(0,0,0,0))',
          filter: `blur(${S * 0.05}px)`,
          transform: `translateY(${tiltX * 0.9}px)`,
        }}
      />
      {/* orange glow behind the dial */}
      {glow > 0 ? (
        <div
          style={{
            ...abs,
            left: -S * 0.3,
            top: -S * 0.3,
            width: S * 1.6,
            height: S * 1.6,
            borderRadius: '50%',
            background: `radial-gradient(closest-side, rgba(255,107,44,${0.35 * glow + 0.25 * pulse}), rgba(255,107,44,0))`,
          }}
        />
      ) : null}
      <div
        style={{
          ...abs,
          width: S,
          height: S,
          transformStyle: 'preserve-3d',
          transform: `rotateX(${tiltX}deg) rotateY(${spinY}deg) rotateZ(${angle}deg)`,
        }}
      >
        {/* body: stacked slices, bottom first */}
        {Array.from({length: layers}).map((_, i) => {
          const k = i / (layers - 1); // 0 = bottom, 1 = top
          const seam = Math.abs(k - 0.42) < 0.012; // lid seam
          const shade = 0.55 + 0.45 * k;
          return (
            <div
              key={i}
              style={{
                ...abs,
                width: S,
                height: S,
                borderRadius: S * R,
                background: seam ? '#8E8E93' : `linear-gradient(${lightDir}deg, ${p.side[0]}, ${p.side[1]})`,
                filter: seam ? undefined : `brightness(${shade})`,
                transform: `translateZ(${-depth + i * step}px)`,
              }}
            />
          );
        })}
        {/* lid top face */}
        <div
          style={{
            ...abs,
            width: S,
            height: S,
            borderRadius: S * R,
            background: `radial-gradient(circle at 30% 20%, rgba(255,255,255,0.55), rgba(255,255,255,0) 55%), linear-gradient(${lightDir}deg, ${p.top[0]}, ${p.top[1]})`,
            boxShadow: `inset 0 0 ${S * 0.03}px rgba(0,0,0,0.12)`,
            transform: 'translateZ(0.5px)',
          }}
        >
          <Marks S={S} color={p.mark} />
        </div>
        {/* dial: knurled aluminium cylinder rising from the lid */}
        {Array.from({length: dialLayers}).map((_, i) => (
          <div
            key={`d${i}`}
            style={{
              ...abs,
              left: dx - dr,
              top: dy - dr,
              width: dr * 2,
              height: dr * 2,
              borderRadius: '50%',
              background: `repeating-conic-gradient(from ${dial}deg, #DADBDE 0deg 2.5deg, #A4A6AB 2.5deg 5deg)`,
              filter: `brightness(${0.8 + 0.25 * (i / (dialLayers - 1))})`,
              transform: `translateZ(${-depth * 0.14 + (i / (dialLayers - 1)) * (depth * 0.14 + rise)}px)`,
            }}
          />
        ))}
        <DialFace S={S} dial={dial} angle={angle} style={{...abs, left: dx - dr, top: dy - dr, transform: `translateZ(${rise + 1}px)`}} pulse={pulse} />
        {/* click ripple on the lid around the dial */}
        {clicks.map((c) => (
          <Ripple key={c} at={c} x={dx} y={dy} r={dr} z={rise + 2} />
        ))}
        <div style={{...abs, width: S, height: S, transform: `translateZ(${rise + 3}px)`}}>
          {clicks.map((c) => (
            <Sparks key={c} at={c} x={dx} y={dy} radius={dr} />
          ))}
        </div>
      </div>
    </div>
  );
};

/** LED ring, speaker dots and pairing button, in the corner opposite the dial. */
const Marks: React.FC<{S: number; color: string}> = ({S, color}) => {
  const r = 0.066 * S;
  const dot = 0.016 * S;
  const gap = 0.03 * S;
  const x = 0.2 * S;
  const dots: [number, number][] = [];
  for (let row = 0; row < 4; row++) for (let col = 0; col < 5 - (row % 2); col++) dots.push([col - (4 - (row % 2)) / 2, row - 1.5]);
  return (
    <>
      <div style={{position: 'absolute', left: x - r, top: 0.48 * S - r, width: r * 2, height: r * 2, borderRadius: '50%', border: `${0.011 * S}px solid ${color}`, boxSizing: 'border-box'}} />
      {dots.map(([c, rw], n) => (
        <div key={n} style={{position: 'absolute', left: x + c * gap - dot / 2, top: 0.645 * S + rw * gap * 0.86 - dot / 2, width: dot, height: dot, borderRadius: '50%', background: color}} />
      ))}
      <div style={{position: 'absolute', left: x - r, top: 0.81 * S - r, width: r * 2, height: r * 2, borderRadius: '50%', background: color}} />
    </>
  );
};

/** Brushed-aluminium top of the dial with its two index grooves. */
const DialFace: React.FC<{S: number; dial: number; angle: number; style: React.CSSProperties; pulse: number}> = ({S, dial, angle, style, pulse}) => {
  const d = DIAL.r * S * 2;
  return (
    <div style={{...style, width: d, height: d, borderRadius: '50%', overflow: 'hidden'}}>
      {/* radial brushing: fine sectors, the highlight stays put while the metal turns */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background: `radial-gradient(circle, rgba(255,255,255,0.25), rgba(255,255,255,0) 30%), conic-gradient(from ${-angle}deg, #C9CBCF, #F4F5F7 45deg, #B7B9BE 100deg, #D9DBDF 180deg, #F2F3F5 225deg, #AEB0B5 290deg, #C9CBCF)`,
        }}
      />
      {/* bevel */}
      <div style={{position: 'absolute', inset: 0, borderRadius: '50%', boxShadow: `inset 0 0 0 ${d * 0.018}px rgba(255,255,255,0.7), inset 0 0 ${d * 0.06}px rgba(0,0,0,0.35)`}} />
      {/* grooves */}
      <div style={{position: 'absolute', inset: 0, transform: `rotate(${dial - 45}deg)`}}>
        {[-1, 1].map((s) => (
          <div
            key={s}
            style={{
              position: 'absolute',
              left: d / 2 - d * 0.012,
              top: s < 0 ? d * 0.1 : d * 0.62,
              width: d * 0.024,
              height: d * 0.28,
              borderRadius: d,
              background: 'rgba(70,72,78,0.85)',
              boxShadow: '1px 0 0 rgba(255,255,255,0.6)',
            }}
          />
        ))}
      </div>
      <div style={{position: 'absolute', inset: 0, borderRadius: '50%', background: C.accent, opacity: pulse * 0.25, mixBlendMode: 'screen'}} />
    </div>
  );
};

const Ripple: React.FC<{at: number; x: number; y: number; r: number; z: number}> = ({at, x, y, r, z}) => {
  const f = useCurrentFrame();
  const t = f - at;
  if (t < 0 || t > 16) return null;
  const p = t / 16;
  const s = 1 + p * 0.9;
  return (
    <div
      style={{
        position: 'absolute',
        left: x - r * s,
        top: y - r * s,
        width: r * 2 * s,
        height: r * 2 * s,
        borderRadius: '50%',
        border: `${r * 0.06 * (1 - p) + 1}px solid ${C.accent}`,
        boxShadow: `0 0 ${r * 0.3}px ${C.accent}`,
        opacity: 1 - p,
        transform: `translateZ(${z}px)`,
      }}
    />
  );
};
