import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse as parseYaml } from 'yaml'

export type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete'

export type OpenApiParam = {
  name: string
  in: 'path' | 'query' | 'header'
  required?: boolean
  schema?: { type?: string; format?: string; enum?: string[] }
  $ref?: string
}

export type OpenApiOp = {
  operationId: string
  summary?: string
  description?: string
  method: HttpMethod
  path: string
  parameters: OpenApiParam[]
  requestBodyRequired: boolean
  hasJsonBody: boolean
  write: boolean
}

type RawDoc = {
  paths?: Record<
    string,
    Partial<
      Record<
        HttpMethod,
        {
          operationId?: string
          summary?: string
          description?: string
          parameters?: OpenApiParam[]
          requestBody?: {
            required?: boolean
            content?: Record<string, unknown>
          }
        }
      >
    >
  >
}

const WRITE_METHODS = new Set<HttpMethod>(['post', 'put', 'patch', 'delete'])

export function openApiPath(): string {
  const here = dirname(fileURLToPath(import.meta.url))
  // dist/ -> ../openapi or src/ -> ../openapi
  return join(here, '..', '..', 'openapi', 'openapi.yaml')
}

export function loadOperations(specPath = openApiPath()): OpenApiOp[] {
  const doc = parseYaml(readFileSync(specPath, 'utf8')) as RawDoc
  const ops: OpenApiOp[] = []

  for (const [path, item] of Object.entries(doc.paths ?? {})) {
    if (!item) continue
    for (const method of ['get', 'post', 'put', 'patch', 'delete'] as HttpMethod[]) {
      const op = item[method]
      if (!op?.operationId) continue
      const parameters = Array.isArray(op.parameters) ? op.parameters : []
      const hasJsonBody = Boolean(op.requestBody?.content?.['application/json'])
      ops.push({
        operationId: op.operationId,
        summary: op.summary,
        description: op.description,
        method,
        path,
        parameters,
        requestBodyRequired: Boolean(op.requestBody?.required),
        hasJsonBody,
        write: WRITE_METHODS.has(method),
      })
    }
  }

  return ops.sort((a, b) => a.operationId.localeCompare(b.operationId))
}

export function resolveParamName(param: OpenApiParam): string | null {
  if (param.$ref?.endsWith('/OrganizationId')) return null // injected from env
  if (param.$ref?.endsWith('/IdempotencyKey')) return null // auto
  if (param.in === 'header') return null
  return param.name
}
