export type Lang = 'en' | 'ur';

/** All on-screen text, English and Roman Urdu. */
export const copy = {
  en: {
    hook1: 'Your earbuds case has a dial.',
    hook2: 'Your Mac never knew.',
    hook3: 'Until now.',
    tagline: 'The CMF Buds Pro 2 dial,\nnow a Mac controller.',
    turn: 'Turn',
    triple: 'Triple-press',
    press: 'Press',
    montage: ['Scroll anything', 'Flip slides', 'Seek video', 'Brightness', 'Volume'],
    radialTitle: 'Triple-press for the radial menu',
    features: ['11 modes', 'Per-app profiles', 'Macros & Shortcuts', 'Updates itself'],
    cta: 'Free for Mac',
    ctaSub: 'Link in bio',
    made: 'Made with ♥ by Taqi Saeed',
    // Short reel: radial
    rHook: 'Triple-press your dial.',
    rTurn: 'Turn to pick a mode',
    rPress: 'Press to choose',
    rDone: 'Now the dial scrolls.',
    // Short reel: profiles
    pHook: 'It knows which app\nyou’re in.',
    pApps: [
      {app: 'Keynote', mode: 'Slides'},
      {app: 'Safari', mode: 'Scroll'},
      {app: 'QuickTime', mode: 'Video Seek'},
    ],
    pProfile: 'Profile',
    pEnd: 'One dial. Every app.',
  },
  ur: {
    hook1: 'Aapke earbuds case\nmein ek dial hai.',
    hook2: 'Aapka Mac ab tak\nanjaan tha.',
    hook3: 'Ab nahi.',
    tagline: 'CMF Buds Pro 2 ka dial,\nab Mac controller.',
    turn: 'Ghumaein',
    triple: 'Triple-press',
    press: 'Press',
    montage: ['Kuch bhi scroll karein', 'Slides badlein', 'Video seek', 'Brightness', 'Volume'],
    radialTitle: 'Triple-press = radial menu',
    features: ['11 modes', 'Har app ka profile', 'Macros & Shortcuts', 'Khud update hota hai'],
    cta: 'Mac ke liye free',
    ctaSub: 'Link bio mein',
    made: 'Made with ♥ by Taqi Saeed',
    rHook: 'Dial ko triple-press\nkarein.',
    rTurn: 'Ghuma kar mode chunein',
    rPress: 'Press se select',
    rDone: 'Ab dial scroll karta hai.',
    pHook: 'Ye jaanta hai aap\nkis app mein hain.',
    pApps: [
      {app: 'Keynote', mode: 'Slides'},
      {app: 'Safari', mode: 'Scroll'},
      {app: 'QuickTime', mode: 'Video Seek'},
    ],
    pProfile: 'Profile',
    pEnd: 'Ek dial. Har app.',
  },
} as const;

export type Copy = (typeof copy)['en'] | (typeof copy)['ur'];
