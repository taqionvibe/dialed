// Renders every reel in English and Roman Urdu to out/*.mp4.
import {execSync} from 'node:child_process';
const reels = [['Hero', 'Hero'], ['Radial', 'RadialMenu'], ['Profiles', 'Profiles']];
for (const lang of ['en', 'ur']) {
  for (const [id, name] of reels) {
    const out = `out/Dialed-${name}-${lang.toUpperCase()}.mp4`;
    console.log(`▸ ${out}`);
    execSync(`npx remotion render src/index.ts ${id}-${lang} ${out} --codec=h264 --crf=16 --log=error`, {stdio: 'inherit'});
  }
}
