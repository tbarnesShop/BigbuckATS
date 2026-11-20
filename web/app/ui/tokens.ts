/** Shared visual roles for every BigBuck surface. */
export const color = {
  background: 'var(--bb-bg)',
  surface: 'var(--bb-surface)',
  surfaceSubtle: 'var(--bb-surface-subtle)',
  text: 'var(--bb-text)',
  textMuted: 'var(--bb-text-muted)',
  border: 'var(--bb-border)',
  controlBorder: 'var(--bb-control-border)',
  accent: 'var(--bb-accent)',
  onAccent: 'var(--bb-on-accent)',
  imageText: 'var(--bb-image-text)',
  accentSubtle: 'var(--bb-accent-subtle)',
  accentHover: 'var(--bb-accent-hover)',
  success: 'var(--bb-success)',
  warning: 'var(--bb-warning)',
  danger: 'var(--bb-danger)',
  focus: 'var(--bb-focus)',
} as const

export const font = {
  ui: "'IBM Plex Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  code: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
} as const
export const type = {
  page: '24px',
  section: '16px',
  body: '14px',
  meta: '13px',
  badge: '12px',
  prose: '15px',
  code: '13px',
} as const
export const space = { xs: '4px', sm: '8px', md: '12px', lg: '16px', xl: '24px', xxl: '32px' } as const
export const geometry = {
  control: '6px',
  panel: '8px',
  badge: '4px',
  controlHeight: '36px',
  touchHeight: '44px',
  navWidth: '232px',
} as const
export const motion = { rowSettle: '120ms ease', inkReveal: '180ms ease' } as const

type Theme = Record<string, string>
export const lightTheme: Theme = {
  '--bb-bg': '#F7F8FA',
  '--bb-surface': '#FFFFFF',
  '--bb-surface-subtle': '#EEF0F4',
  '--bb-text': '#20242C',
  '--bb-text-muted': '#596170',
  '--bb-border': '#D7DBE3',
  '--bb-control-border': '#808896',
  '--bb-accent': '#6246D9',
  '--bb-accent-hover': '#5135BD',
  '--bb-accent-pressed': '#422A9F',
  '--bb-on-accent': '#FFFFFF',
  '--bb-accent-subtle': '#EEE9FF',
  '--bb-focus': '#6246D9',
  '--bb-success': '#176B45',
  '--bb-success-bg': '#E8F4ED',
  '--bb-warning': '#855700',
  '--bb-warning-bg': '#FFF3D6',
  '--bb-danger': '#B42332',
  '--bb-danger-bg': '#FDECEF',
  '--bb-disabled': '#596170',
  '--bb-disabled-bg': '#EEF0F4',
  '--bb-shadow': '0 8px 24px rgb(32 36 44 / 14%)',
  '--bb-overlay': 'rgb(16 18 23 / 45%)',
}
export const darkTheme: Theme = {
  '--bb-bg': '#101217',
  '--bb-surface': '#191C24',
  '--bb-surface-subtle': '#222631',
  '--bb-text': '#F1F2F5',
  '--bb-text-muted': '#ABB2C0',
  '--bb-border': '#373D4B',
  '--bb-control-border': '#788298',
  '--bb-accent': '#A594FF',
  '--bb-accent-hover': '#B8ABFF',
  '--bb-accent-pressed': '#C6BCFF',
  '--bb-on-accent': '#151120',
  '--bb-accent-subtle': '#2D2645',
  '--bb-focus': '#A594FF',
  '--bb-success': '#78D6A5',
  '--bb-success-bg': '#17372B',
  '--bb-warning': '#EAC16B',
  '--bb-warning-bg': '#3B301B',
  '--bb-danger': '#FF9AA6',
  '--bb-danger-bg': '#40232C',
  '--bb-disabled': '#ABB2C0',
  '--bb-disabled-bg': '#222631',
  '--bb-shadow': '0 8px 24px rgb(0 0 0 / 32%)',
  '--bb-overlay': 'rgb(0 0 0 / 60%)',
}
const foundation: Theme = {
  '--bb-font-body': font.ui,
  '--bb-font-code': font.code,
  ...Object.fromEntries(Object.entries(type).map(([key, value]) => [`--bb-type-${key}`, value])),
  ...Object.fromEntries(Object.entries(space).map(([key, value]) => [`--bb-space-${key}`, value])),
  ...Object.fromEntries(Object.entries(geometry).map(([key, value]) => [`--bb-${key}`, value])),
  '--bb-motion-control': motion.rowSettle,
  '--bb-image-text': '#FFFFFF',
  '--bb-brand-surface': '#FFFFFF',
}
const declarations = (values: Theme) =>
  Object.entries(values)
    .map(([name, value]) => `${name}:${value};`)
    .join('')
export const themeCss = [
  '@layer bb-base, bb-kit, bb-surfaces, rmx;',
  `:root{color-scheme:light;${declarations(foundation)}${declarations(lightTheme)}}`,
  `@media(prefers-color-scheme:dark){:root:not([data-theme="light"]){color-scheme:dark;${declarations(darkTheme)}}}`,
  `:root[data-theme="dark"]{color-scheme:dark;${declarations(darkTheme)}}`,
  `@layer bb-base{
    body{margin:0;background:var(--bb-bg);color:var(--bb-text);font:400 var(--bb-type-body)/1.45 var(--bb-font-body);}
    h1,h2,h3{font-family:var(--bb-font-body);font-weight:600;}
    button,input,select,textarea{font:inherit;}
    code,pre,kbd,samp{font-family:var(--bb-font-code);}
    a{color:var(--bb-accent);}
    :focus-visible{outline:2px solid var(--bb-focus);outline-offset:2px;box-shadow:none;}
    @media(prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:0.01ms!important;transition-duration:0.01ms!important;scroll-behavior:auto!important;}}
  }`,
].join('\n')
export const THEMES = ['system', 'light', 'dark'] as const
export type ThemeChoice = (typeof THEMES)[number]
