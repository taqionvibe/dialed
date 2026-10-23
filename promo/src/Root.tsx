import React from 'react';
import {Composition} from 'remotion';
import {DURATIONS, HeroReel, ProfilesReel, RadialReel} from './reels';
import {FPS, H, W} from './theme';

export const Root: React.FC = () => (
  <>
    {(['en', 'ur'] as const).map((lang) => (
      <React.Fragment key={lang}>
        <Composition id={`Hero-${lang}`} component={HeroReel} durationInFrames={DURATIONS.hero} fps={FPS} width={W} height={H} defaultProps={{lang}} />
        <Composition id={`Radial-${lang}`} component={RadialReel} durationInFrames={DURATIONS.radial} fps={FPS} width={W} height={H} defaultProps={{lang}} />
        <Composition id={`Profiles-${lang}`} component={ProfilesReel} durationInFrames={DURATIONS.profiles} fps={FPS} width={W} height={H} defaultProps={{lang}} />
      </React.Fragment>
    ))}
  </>
);
