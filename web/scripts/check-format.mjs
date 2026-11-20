import { execFileSync } from 'node:child_process'
const base = process.env.FORMAT_BASE || 'origin/main'
const files = execFileSync(
  'git',
  ['diff', '--name-only', '-z', '--relative', '--diff-filter=ACM', base, '--', '*.ts', '*.tsx', '*.mjs'],
  { encoding: 'utf8' },
)
  .split('\0')
  .filter((file) => file && !file.startsWith('../') && file !== 'app/graphql/generated.ts')
if (files.length) execFileSync('pnpm', ['exec', 'prettier', '--check', ...files], { stdio: 'inherit' })
