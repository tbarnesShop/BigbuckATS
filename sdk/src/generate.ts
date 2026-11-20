import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse as parseYaml } from 'yaml'

import type { HttpMethod, OpenApiOperation } from './openapi.js'

type RawDoc = {
  paths?: Record<
    string,
    Partial<
      Record<
        HttpMethod,
        {
          operationId?: string
          summary?: string
          parameters?: Array<{
            name?: string
            in?: 'path' | 'query' | 'header'
            required?: boolean
            $ref?: string
          }>
          requestBody?: {
            required?: boolean
            content?: Record<string, unknown>
          }
        }
      >
    > & { parameters?: Array<{ name?: string; in?: string; required?: boolean; $ref?: string }> }
  >
}

const WRITE_METHODS = new Set<HttpMethod>(['post', 'put', 'patch', 'delete'])

const here = dirname(fileURLToPath(import.meta.url))
const openapiPath = join(here, '..', '..', 'openapi', 'openapi.yaml')
const outDir = join(here, '..', 'generated')
mkdirSync(outDir, { recursive: true })

const doc = parseYaml(readFileSync(openapiPath, 'utf8')) as RawDoc
const operations: OpenApiOperation[] = []

for (const [path, item] of Object.entries(doc.paths ?? {})) {
  if (!item) continue
  for (const method of ['get', 'post', 'put', 'patch', 'delete'] as HttpMethod[]) {
    const op = item[method]
    if (!op?.operationId) continue
    const parameters: OpenApiOperation['parameters'] = []
    for (const param of [...(item.parameters ?? []), ...(op.parameters ?? [])]) {
      if (param.$ref?.endsWith('/OrganizationId') || param.$ref?.endsWith('/IdempotencyKey')) continue
      if (param.in === 'header' || !param.name || !param.in) continue
      if (param.in !== 'path' && param.in !== 'query') continue
      parameters.push({
        name: param.name,
        in: param.in,
        required: Boolean(param.required || param.in === 'path'),
      })
    }

    operations.push({
      operationId: op.operationId,
      summary: op.summary,
      method,
      path,
      write: WRITE_METHODS.has(method),
      hasJsonBody: Boolean(op.requestBody?.content?.['application/json']),
      parameters,
    })
  }
}

operations.sort((a, b) => a.operationId.localeCompare(b.operationId))
const outPath = join(outDir, 'operations.json')
writeFileSync(
  outPath,
  `${JSON.stringify({ generatedAt: new Date().toISOString(), operations }, null, 2)}\n`,
)
console.log(`Wrote ${operations.length} operations → ${outPath}`)
