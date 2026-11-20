import { execFile } from 'node:child_process'
import { createHash } from 'node:crypto'
import { mkdir, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js'
import { apiCatalog, repoRoot } from './catalog.ts'
import { apiBase, labRequest, requireLab, result, LabError } from './client.ts'
import type { CatalogItem, Result } from './types.ts'

function environment(agent = false): Record<string, string> {
  const current = requireLab()
  return {
    PATH: process.env.PATH ?? '',
    NODE_ENV: 'development',
    BIGBUCK_API_URL: apiBase(),
    BIGBUCK_TOKEN: agent ? current.lab.agentToken : current.lab.toolToken,
    BIGBUCK_DEMO_GENERATION: String(current.lab.generation),
    BIGBUCK_MCP_ALLOW_WRITES: 'true',
    // Behind a public API, children need the edge secret too; edge-fetch.mjs adds it to their requests.
    ...(process.env.BIGBUCK_EDGE_SECRET
      ? {
          BIGBUCK_EDGE_SECRET: process.env.BIGBUCK_EDGE_SECRET,
          NODE_OPTIONS: `--import=${pathToFileURL(resolve(process.env.BIGBUCK_WEB_ROOT ?? process.cwd(), 'edge-fetch.mjs')).href}`,
        }
      : {}),
  }
}

/** Disposable per-token CLI directories: the repo's tmp locally, the only writable disk (/tmp) on Vercel. */
const scratchRoot = () =>
  process.env.VERCEL ? resolve(tmpdir(), 'bigbuck-lab-cli') : resolve(repoRoot, 'tmp/lab-cli')
async function withMcp<T>(action: (client: Client) => Promise<T>): Promise<T> {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [resolve(repoRoot, 'mcp/dist/server.js')],
    cwd: repoRoot,
    env: environment(true),
    stderr: 'pipe',
  })
  const client = new Client({ name: 'bigbuck-lab', version: '1.0.0' })
  try {
    await client.connect(transport)
    return await action(client)
  } finally {
    await client.close()
  }
}
export async function mcpCatalog(): Promise<CatalogItem[]> {
  return withMcp(async (client) => {
    const catalog = await client.listTools()
    const api = apiCatalog()
    return catalog.tools.map((tool) => ({
      name: tool.name,
      description: tool.description ?? tool.name,
      write: tool.annotations?.readOnlyHint === false || /write|mutation/i.test(tool.description ?? ''),
      inputSchema: tool.inputSchema as CatalogItem['inputSchema'],
      available: api.find((op) => op.name === tool.name)?.available ?? true,
    }))
  })
}
export function hasStructuredErrors(value: unknown): boolean {
  if (!value || typeof value !== 'object') return false
  if (Array.isArray(value)) return value.some(hasStructuredErrors)
  return Object.entries(value).some(([key, child]) =>
    (key === 'errors' || key === 'userErrors') && Array.isArray(child)
      ? child.length > 0
      : hasStructuredErrors(child),
  )
}
export async function runMcp(name: string, args: Record<string, unknown>): Promise<Result> {
  const start = performance.now()
  return withMcp(async (client) => {
    const catalog = await client.listTools()
    if (!catalog.tools.some((tool) => tool.name === name))
      throw new LabError(400, 'unknown_tool', 'Choose a tool from the MCP catalog.')
    if (apiCatalog().find((op) => op.name === name)?.available === false)
      throw new LabError(
        403,
        'demo_control_blocked',
        'Identity and public-token endpoints are not available in the lab explorer.',
      )
    const call = await client.callTool({ name, arguments: args }, undefined, { timeout: 30000 })
    const content = Array.isArray(call.content) ? call.content : []
    const text = content
      .filter((item: any) => item.type === 'text')
      .map((item: any) => item.text)
      .join('\n')
    let output: unknown = call
    let status = call.isError ? 422 : 200
    const http = text.match(/^HTTP (\d+)\n/)
    if (http) {
      status = Number(http[1])
      try {
        output = JSON.parse(text.slice(http[0].length))
      } catch {
        output = text
      }
    } else {
      try {
        output = JSON.parse(text)
      } catch {
        output = text || call
      }
    }
    return {
      ...result(status, output, start, `${name}(${JSON.stringify(args)})`),
      ok: !call.isError && !hasStructuredErrors(output) && status >= 200 && status < 300,
    }
  })
}
export async function runApi(
  name: string,
  args: Record<string, unknown>,
  idempotencyKey?: string,
): Promise<Result> {
  const start = performance.now()
  const operation = apiCatalog().find((op) => op.name === name)
  if (!operation?.available)
    throw new LabError(403, 'demo_control_blocked', 'Choose an available operation from the catalog.')
  let path = operation.path!
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(args)) {
    if (key === 'body' || value === undefined || value === '') continue
    if (path.includes(`{${key}}`)) path = path.replaceAll(`{${key}}`, encodeURIComponent(String(value)))
    else query.set(key, typeof value === 'object' ? JSON.stringify(value) : String(value))
  }
  if (/\{/.test(path))
    throw new LabError(400, 'missing_path_parameter', 'Fill in all required path parameters.')
  if (query.size) path += `?${query}`
  const response = await labRequest(path, {
    method: operation.method,
    body: operation.method === 'GET' ? undefined : args.body,
    idempotencyKey,
  })
  const quote = (text: string) => "'" + text.replaceAll("'", "'\"'\"'") + "'"
  const example = [
    `curl -X ${operation.method} ${quote(apiBase() + path)}`,
    "  -H 'Authorization: Bearer <your-credential>'",
    "  -H 'Content-Type: application/json'",
    ...(args.body === undefined ? [] : [`  --data ${quote(JSON.stringify(args.body))}`]),
  ].join(' ' + String.fromCharCode(92, 10))
  return { ...result(response.status, response.body, start, `${operation.method} ${path}`), example }
}
export function parseCommand(input: string): string[] {
  if (input.length > 3000)
    throw new LabError(400, 'command_too_long', 'Keep commands under 3,000 characters.')
  const words: string[] = []
  let word = ''
  let quote = ''
  let active = false
  for (const char of input.trim()) {
    if (quote) {
      if (char === quote) quote = ''
      else word += char
      active = true
    } else if (char === '"' || char === "'") {
      quote = char
      active = true
    } else if (/\s/.test(char)) {
      if (active) words.push(word)
      word = ''
      active = false
    } else {
      word += char
      active = true
    }
  }
  if (quote) throw new LabError(400, 'unclosed_quote', 'Close the quote in your command.')
  if (active) words.push(word)
  if (words[0] === 'bigbuck') words.shift()
  if (!words.length) words.push('help')
  if (
    ![
      'help',
      'whoami',
      'config',
      'import',
      'person',
      'job',
      'project',
      'sequence',
      'application',
      'api',
      'gql',
      'graphql',
    ].includes(words[0])
  )
    throw new LabError(
      400,
      'unsupported_command',
      'This terminal runs Big Buck commands, not a system shell.',
    )
  if (words[0] === 'api' && words[1] && words[1] !== 'list' && words[1] !== 'help') {
    const operation = apiCatalog().find((op) => op.name === words[1])
    if (operation?.available === false)
      throw new LabError(
        403,
        'demo_control_blocked',
        'Identity and public-token endpoints are not available in the lab explorer.',
      )
  }
  if (
    words.some((word) => /^--(?:token|as-agent|api-url|org|organization-id|actor|actor-id)(?:=|$)/.test(word))
  )
    throw new LabError(
      403,
      'identity_override_blocked',
      'The lab supplies your role-bound identity and API URL.',
    )
  return words
}
export async function runCli(command: string): Promise<Result> {
  const start = performance.now()
  const current = requireLab()
  const words = parseCommand(command)
  const dir = resolve(
    scratchRoot(),
    createHash('sha256').update(current.lab.toolToken).digest('hex').slice(0, 24),
  )
  await mkdir(dir, { recursive: true })
  await writeFile(
    resolve(dir, 'sample.csv'),
    'name,email\nNova Example,nova@example.test\nEli Example,eli@example.test\n',
  )
  for (let index = 0; index < words.length; index++) {
    const [flag, inline] = words[index].split('=', 2)
    if (['--dir', '--file', '-f'].includes(flag)) {
      const value = inline ?? words[index + 1]
      const allowed = flag === '--dir' ? ['bigbuck', './bigbuck'] : ['sample.csv', './sample.csv']
      if (!allowed.includes(value))
        throw new LabError(
          400,
          'file_boundary',
          'Use --dir ./bigbuck or --file sample.csv; files stay inside your demo directory.',
        )
    }
  }
  if (
    words[0] === 'config' &&
    !words.some((word) => word === '--dir' || word.startsWith('--dir=')) &&
    ['init', 'plan'].includes(words[1])
  )
    words.push('--dir', './bigbuck')
  if (!words.includes('--json') && words[0] !== 'help' && !words.includes('--help')) words.push('--json')
  const executed = await new Promise<{ stdout: string; stderr: string; code: number }>(
    (resolvePromise, reject) => {
      execFile(
        process.execPath,
        [resolve(repoRoot, 'cli/dist/cli.js'), ...words],
        { cwd: dir, env: environment(), timeout: 30000, maxBuffer: 1024 * 1024 },
        (error, stdout, stderr) => {
          if (error && typeof error.code !== 'number')
            return reject(
              new LabError(
                503,
                'cli_unavailable',
                'The CLI could not finish. Check the record before retrying if it started.',
                error.killed || error.signal ? 'unknown' : undefined,
              ),
            )
          resolvePromise({ stdout, stderr, code: typeof error?.code === 'number' ? error.code : 0 })
        },
      )
    },
  )
  let output: unknown = executed.stdout || executed.stderr
  try {
    output = JSON.parse(executed.stdout)
  } catch {
    /* help and tables remain readable */
  }
  return result(executed.code ? 422 : 200, output, start, `bigbuck ${words.join(' ')}`)
}
