import {loadFont} from '@remotion/google-fonts/Inter';

const inter = loadFont('normal', {weights: ['500', '600', '700', '800', '900'], subsets: ['latin']});

export const font = inter.fontFamily;

export const C = {
  accent: '#FF6B2C',
  accentSoft: 'rgba(255,107,44,0.18)',
  bg0: '#0B0B0D',
  bg1: '#18171B',
  card: '#1F1E23',
  stroke: 'rgba(255,255,255,0.10)',
  text: '#FFFFFF',
  dim: 'rgba(255,255,255,0.62)',
  faint: 'rgba(255,255,255,0.35)',
};

export const FPS = 30;
export const W = 1080;
export const H = 1920;

/** Instagram covers ~250 px at the top and ~420 px at the bottom with UI; keep text inside. */
export const SAFE = {top: 260, bottom: 440, side: 80};
