import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

export type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete'

export type OpenApiOperation = {
  operationId: string
  summary?: string
  method: HttpMethod
  path: string
  write: boolean
  hasJsonBody: boolean
  parameters: Array<{ name: string; in: 'path' | 'query' | 'header'; required?: boolean }>
}

type CatalogFile = {
  generatedAt?: string
  operations: OpenApiOperation[]
}

export function operationsPath(): string {
  const here = dirname(fileURLToPath(import.meta.url))
  return join(here, '..', 'generated', 'operations.json')
}

export function loadOperations(catalogPath = operationsPath()): OpenApiOperation[] {
  const raw = JSON.parse(readFileSync(catalogPath, 'utf8')) as CatalogFile
  return raw.operations
}

export function findOperation(
  operationId: string,
  catalogPath = operationsPath(),
): OpenApiOperation | undefined {
  return loadOperations(catalogPath).find((op) => op.operationId === operationId)
}
