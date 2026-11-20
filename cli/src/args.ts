export type ParsedArgs = {
  command: string[]
  flags: Record<string, string | boolean>
  positionals: string[]
}

/** Flags that always take a following string value. Others are boolean unless `--key=value`. */
const STRING_FLAGS = new Set([
  'token',
  'as-agent',
  'org',
  'organization-id',
  'actor',
  'actor-id',
  'api-url',
  'preset',
  'dir',
  'plan-id',
  'plan',
  'file',
  'f',
  'map',
  'source-system',
  'name',
  'n',
  'email',
  'phone',
  'title',
  't',
  'status',
  'job',
  'job-id',
  'person',
  'person-id',
  'key',
  'mailbox',
  'mailbox-id',
  'to',
  'stage',
  'reason',
  'r',
  'body',
  'scopes',
  'description',
  'expires-at',
  'id',
  'domain',
  'company-id',
  'q',
  'query',
  'variables',
  'vars',
  'value',
  'entity',
  'entity-type',
  'entity-id',
  'expected-version',
])

/** Minimal argv parser: `bigbuck person create --name Ada --json` */
export function parseArgs(argv: string[]): ParsedArgs {
  const args = argv.slice(2)
  const command: string[] = []
  const flags: Record<string, string | boolean> = {}
  const positionals: string[] = []
  let i = 0
  while (i < args.length && !args[i].startsWith('-')) {
    command.push(args[i])
    i += 1
  }
  while (i < args.length) {
    const token = args[i]
    if (token.startsWith('--')) {
      const eq = token.indexOf('=')
      if (eq !== -1) {
        flags[token.slice(2, eq)] = token.slice(eq + 1)
        i += 1
        continue
      }
      const key = token.slice(2)
      const next = args[i + 1]
      if (STRING_FLAGS.has(key) && next !== undefined && !next.startsWith('-')) {
        flags[key] = next
        i += 2
      } else {
        flags[key] = true
        i += 1
      }
      continue
    }
    if (token.startsWith('-') && token.length === 2) {
      const key = token.slice(1)
      const next = args[i + 1]
      if (STRING_FLAGS.has(key) && next !== undefined && !next.startsWith('-')) {
        flags[key] = next
        i += 2
      } else {
        flags[key] = true
        i += 1
      }
      continue
    }
    positionals.push(token)
    i += 1
  }
  return { command, flags, positionals }
}

export function flagString(flags: Record<string, string | boolean>, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = flags[key]
    if (typeof value === 'string') return value
  }
  return undefined
}

export function flagBool(flags: Record<string, string | boolean>, ...keys: string[]): boolean {
  for (const key of keys) {
    const value = flags[key]
    if (value === true) return true
    if (typeof value === 'string' && ['1', 'true', 'yes'].includes(value.toLowerCase())) return true
  }
  return false
}
