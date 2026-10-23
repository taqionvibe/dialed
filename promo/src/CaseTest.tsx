import React from 'react';
import {AbsoluteFill} from 'remotion';
import {CaseModel} from './CaseModel';

/** Dev-only: the case model in a few poses. */
export const CaseTest: React.FC = () => (
  <AbsoluteFill style={{background: '#0B0B0D', display: 'flex', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-around', padding: 60}}>
    {[
      {tiltX: 0, angle: 45},
      {tiltX: 35, angle: 45},
      {tiltX: 62, angle: 45, spinY: 0},
      {tiltX: 70, angle: 20},
      {tiltX: 30, angle: 45, color: 'orange' as const},
      {tiltX: 50, angle: 45, color: 'dark' as const},
    ].map((p, i) => (
      <div key={i} style={{width: 460, height: 560, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
        <CaseModel size={280} dial={i * 25} glow={i === 1 ? 1 : 0} {...p} />
      </div>
    ))}
  </AbsoluteFill>
);
