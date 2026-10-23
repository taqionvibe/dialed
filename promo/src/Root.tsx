import React from 'react';
import {Composition} from 'remotion';
import {Hero2, HERO2_LEN, Profiles2, PROFILES2_LEN, Radial2, RADIAL2_LEN} from './reels2';
import {FPS, H, W} from './theme';

export const Root: React.FC = () => (
  <>
    {(['en', 'ur'] as const).map((lang) => (
      <React.Fragment key={lang}>
        <Composition id={`Hero-${lang}`} component={Hero2} durationInFrames={HERO2_LEN} fps={FPS} width={W} height={H} defaultProps={{lang}} />
        <Composition id={`Radial-${lang}`} component={Radial2} durationInFrames={RADIAL2_LEN} fps={FPS} width={W} height={H} defaultProps={{lang}} />
        <Composition id={`Profiles-${lang}`} component={Profiles2} durationInFrames={PROFILES2_LEN} fps={FPS} width={W} height={H} defaultProps={{lang}} />
      </React.Fragment>
    ))}
  </>
);
