import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { loadOperations, resolveParamName } from './openapi.js'

const here = dirname(fileURLToPath(import.meta.url))
const outDir = join(here, '..', 'generated')
mkdirSync(outDir, { recursive: true })

const ops = loadOperations()
const catalog = ops.map((op) => {
  const properties: Record<string, unknown> = {}
  const required: string[] = []

  for (const param of op.parameters) {
    const name = resolveParamName(param)
    if (!name) continue
    properties[name] = {
      type: param.schema?.type ?? 'string',
      description: `${param.in} parameter`,
      ...(param.schema?.enum ? { enum: param.schema.enum } : {}),
    }
    if (param.required || param.in === 'path') required.push(name)
  }

  if (op.hasJsonBody) {
    properties.body = {
      type: 'object',
      description: 'JSON request body (matches OpenAPI requestBody)',
      additionalProperties: true,
    }
    if (op.requestBodyRequired) required.push('body')
  }

  return {
    name: op.operationId,
    description: op.summary ?? op.operationId,
    method: op.method,
    path: op.path,
    write: op.write,
    hasJsonBody: op.hasJsonBody,
    inputSchema: {
      type: 'object',
      properties,
      required: required.length ? required : undefined,
      additionalProperties: false,
    },
  }
})

const jsonPath = join(outDir, 'tools.json')
writeFileSync(jsonPath, `${JSON.stringify({ generatedAt: new Date().toISOString(), tools: catalog }, null, 2)}\n`)

const mdPath = join(outDir, 'TOOLS.md')
const lines = [
  '# Big Buck MCP tools',
  '',
  `Generated from \`openapi/openapi.yaml\` (${catalog.length} operations).`,
  '',
  'Write tools require `BIGBUCK_MCP_ALLOW_WRITES=true`.',
  '',
  '| Tool | Method | Path | Write |',
  '|---|---|---|---|',
  ...catalog.map(
    (t) => `| \`${t.name}\` | ${t.method.toUpperCase()} | \`${t.path}\` | ${t.write ? 'yes' : ''} |`,
  ),
  '',
]
writeFileSync(mdPath, lines.join('\n'))

console.log(`Wrote ${catalog.length} tools → ${jsonPath}`)
