import {Lang} from './copy';

/** Owner-focused copy for the v2 reels (English + Roman Urdu). */
export const copy2 = {
  en: {
    eyebrow: 'CMF Buds Pro 2 owners',
    own1: 'Got CMF\nBuds Pro 2?',
    own2: 'You turn this dial\nfor music volume…',
    own3: '…and that’s it?',
    build: 'What if it could\ncontrol your Mac?',
    drop: 'It can now.',
    clarify: 'A free Mac app\nfor your CMF dial',
    montage: ['Scroll anything', 'Flip slides', 'Seek video', 'Brightness', 'Volume'],
    radial: 'Triple-press →\nradial menu',
    features: ['11 modes', 'Per-app profiles', 'Macros & Shortcuts', 'Updates itself'],
    only: 'Only for CMF Buds Pro 2',
    cta: 'Free for Mac',
    ctaSub: 'Link in bio',
    // Radial short
    rHook: 'Triple-press\nyour dial.',
    rTurn: 'Turn to pick a mode',
    rPress: 'Press to choose',
    rDone: 'Now it scrolls.',
    // Profiles short
    pHook: 'Your CMF dial knows\nwhich app you’re in.',
    pEnd: 'One dial.\nEvery app.',
  },
  ur: {
    eyebrow: 'CMF Buds Pro 2 walon ke liye',
    own1: 'CMF Buds Pro 2\nhain aapke paas?',
    own2: 'Is dial se sirf\ngaanon ka volume…',
    own3: '…bas itna hi?',
    build: 'Agar ye aapka Mac\ncontrol kare?',
    drop: 'Ab karta hai.',
    clarify: 'Aapke CMF dial ke liye\nfree Mac app',
    montage: ['Kuch bhi scroll', 'Slides badlein', 'Video seek', 'Brightness', 'Volume'],
    radial: 'Triple-press =\nradial menu',
    features: ['11 modes', 'Har app ka profile', 'Macros & Shortcuts', 'Khud update'],
    only: 'Sirf CMF Buds Pro 2 ke liye',
    cta: 'Mac ke liye free',
    ctaSub: 'Link bio mein',
    rHook: 'Dial ko\ntriple-press karein.',
    rTurn: 'Ghuma kar mode chunein',
    rPress: 'Press se select',
    rDone: 'Ab ye scroll karta hai.',
    pHook: 'Aapka CMF dial\njaanta hai aap\nkis app mein hain.',
    pEnd: 'Ek dial.\nHar app.',
  },
} satisfies Record<Lang, Record<string, string | string[]>>;
