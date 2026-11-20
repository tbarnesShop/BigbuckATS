import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { parse } from 'yaml'
import type { CatalogItem, Schema } from './types.ts'

// On Vercel the project root is web/ and the build copies the repo files the app reads into web/.repo.
export const repoRoot = resolve(
  process.env.BIGBUCK_WEB_ROOT ?? process.cwd(),
  process.env.VERCEL ? '.repo' : '..',
)
export function contract() {
  return parse(readFileSync(resolve(repoRoot, 'openapi/openapi.yaml'), 'utf8')) as Record<string, any>
}
export function resolveSchema(schema: Schema = {}, document = contract(), depth = 0): Schema {
  if (depth > 8) return { type: 'object' }
  if (schema.$ref) {
    const target = schema.$ref
      .slice(2)
      .split('/')
      .reduce((node: any, key: string) => node?.[key], document)
    return resolveSchema(target ?? {}, document, depth + 1)
  }
  const result = { ...schema }
  if (result.properties)
    result.properties = Object.fromEntries(
      Object.entries(result.properties).map(([key, value]) => [
        key,
        resolveSchema(value, document, depth + 1),
      ]),
    )
  if (result.items) result.items = resolveSchema(result.items, document, depth + 1)
  return result
}
export function apiCatalog(): CatalogItem[] {
  const doc = contract()
  return Object.entries(doc.paths)
    .flatMap(([path, methods]: [string, any]) =>
      Object.entries(methods).flatMap(([method, raw]: [string, any]) => {
        if (!['get', 'post', 'put', 'patch', 'delete'].includes(method)) return []
        const parameters = [...(methods.parameters ?? []), ...(raw.parameters ?? [])].map((p: any) =>
          p.$ref
            ? p.$ref
                .slice(2)
                .split('/')
                .reduce((n: any, k: string) => n?.[k], doc)
            : p,
        )
        const properties: Record<string, Schema> = {}
        const required: string[] = []
        for (const param of parameters) {
          if (!param || param.in === 'header') continue
          properties[param.name] = {
            ...resolveSchema(param.schema, doc),
            description: `${param.in}: ${param.description ?? ''}`,
          }
          if (param.required) required.push(param.name)
        }
        const bodySchema = resolveSchema(raw.requestBody?.content?.['application/json']?.schema, doc)
        if (raw.requestBody?.content?.['application/json']) {
          properties.body = { type: 'object', description: 'JSON request body' }
          if (raw.requestBody.required) required.push('body')
        }
        return [
          {
            name: raw.operationId,
            description: raw.summary ?? raw.operationId,
            method: method.toUpperCase(),
            path: `/v1${path}`,
            write: method !== 'get',
            inputSchema: { type: 'object', properties, required },
            bodySchema,
            available: !/^\/(sessions|oauth|organizations|public|credentials|agents)(\/|$)/.test(path),
          },
        ]
      }),
    )
    .sort((a, b) => a.name.localeCompare(b.name))
}
export function cliHelp(): string {
  const source = readFileSync(resolve(repoRoot, 'cli/src/cli.ts'), 'utf8')
  return source.match(/const HELP = `([\s\S]*?)`/)?.[1] ?? 'CLI help unavailable'
}
export function sampleValue(schema: Schema, field = ''): unknown {
  if (schema.example !== undefined) return schema.example
  if (schema.default !== undefined) return schema.default
  if (schema.enum?.length) return schema.enum[0]
  if (schema.type === 'object' || schema.properties)
    return Object.fromEntries(
      Object.entries(schema.properties ?? {})
        .filter(([key]) => schema.required?.includes(key))
        .map(([key, value]) => [key, sampleValue(value, key)]),
    )
  if (schema.type === 'array') return []
  if (schema.type === 'integer' || schema.type === 'number') return 1
  if (schema.type === 'boolean') return false
  if (field === 'display_name') return 'Nova Example'
  if (field === 'email' || field === 'primary_email') return 'nova@example.test'
  if (field === 'name') return 'Lab talent pool'
  return ''
}
