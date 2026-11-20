#!/usr/bin/env node
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

import { callApi, configFromEnv } from './client.js'
import { CURATED_TOOLS } from './curated.js'
import { callGraphql } from './graphql.js'
import { loadOperations, resolveParamName } from './openapi.js'

type ToolDef = {
  name: string
  description: string
  method: string
  path: string
  write: boolean
  hasJsonBody: boolean
  inputSchema: {
    type: string
    properties?: Record<string, { type?: string; description?: string; enum?: string[] }>
    required?: string[]
  }
}

function loadCatalog(): ToolDef[] {
  const here = dirname(fileURLToPath(import.meta.url))
  const generated = join(here, '..', 'generated', 'tools.json')
  try {
    const raw = JSON.parse(readFileSync(generated, 'utf8')) as { tools: ToolDef[] }
    return raw.tools
  } catch {
    // Fall back to live OpenAPI parse (dev without generate step).
    return loadOperations().map((op) => {
      const properties: Record<string, { type?: string; description?: string; enum?: string[] }> = {}
      const required: string[] = []
      for (const param of op.parameters) {
        const name = resolveParamName(param)
        if (!name) continue
        properties[name] = { type: param.schema?.type ?? 'string', description: `${param.in} parameter` }
        if (param.required || param.in === 'path') required.push(name)
      }
      if (op.hasJsonBody) {
        properties.body = { type: 'object', description: 'JSON request body' }
        if (op.requestBodyRequired) required.push('body')
      }
      return {
        name: op.operationId,
        description: op.summary ?? op.operationId,
        method: op.method,
        path: op.path,
        write: op.write,
        hasJsonBody: op.hasJsonBody,
        inputSchema: { type: 'object', properties, required },
      }
    })
  }
}

function zodFromJsonSchema(tool: ToolDef): Record<string, z.ZodTypeAny> {
  const shape: Record<string, z.ZodTypeAny> = {}
  const required = new Set(tool.inputSchema.required ?? [])
  for (const [key, schema] of Object.entries(tool.inputSchema.properties ?? {})) {
    let field: z.ZodTypeAny
    if (schema.type === 'object') {
      field = z.record(z.string(), z.any())
    } else if (schema.enum?.length) {
      field = z.enum(schema.enum as [string, ...string[]])
    } else if (schema.type === 'integer' || schema.type === 'number') {
      field = z.number()
    } else if (schema.type === 'boolean') {
      field = z.boolean()
    } else {
      field = z.string()
    }
    shape[key] = required.has(key) ? field : field.optional()
  }
  return shape
}

async function main() {
  const cfg = configFromEnv()
  const tools = loadCatalog()
  const server = new McpServer({
    name: 'bigbuck',
    version: '0.1.0',
  })

  for (const tool of tools) {
    const shape = zodFromJsonSchema(tool)
    const annotations = tool.write
      ? { readOnlyHint: false, destructiveHint: true, openWorldHint: true }
      : { readOnlyHint: true, openWorldHint: true }

    server.registerTool(
      tool.name,
      {
        title: tool.name,
        description: `${tool.description}${tool.write ? ' [write — requires BIGBUCK_MCP_ALLOW_WRITES=true]' : ''}`,
        inputSchema: shape,
        annotations,
      },
      async (args) => {
        try {
          const result = await callApi(
            cfg,
            tool.method,
            tool.path,
            args as Record<string, unknown>,
            { write: tool.write, hasJsonBody: tool.hasJsonBody },
          )
          const text = JSON.stringify(result.body, null, 2)
          return {
            content: [
              {
                type: 'text' as const,
                text: `HTTP ${result.status}\n${text}`,
              },
            ],
            isError: result.status >= 400,
          }
        } catch (error) {
          return {
            content: [{ type: 'text' as const, text: String(error) }],
            isError: true,
          }
        }
      },
    )
  }

  const respond = (result: { status: number; body: unknown }) => {
    const errors = (result.body as { errors?: unknown[] } | null)?.errors
    return {
      content: [{ type: 'text' as const, text: `HTTP ${result.status}\n${JSON.stringify(result.body, null, 2)}` }],
      isError: result.status >= 400 || (Array.isArray(errors) && errors.length > 0),
    }
  }
  const failure = (error: unknown) => ({ content: [{ type: 'text' as const, text: String(error) }], isError: true })

  // GraphQL: curated operations, then a general query tool.
  for (const tool of CURATED_TOOLS) {
    const shape: Record<string, z.ZodTypeAny> = {}
    for (const [name, spec] of Object.entries(tool.variables)) {
      let field: z.ZodTypeAny =
        spec.type === 'integer' ? z.number().int() : spec.type === 'boolean' ? z.boolean() : spec.type === 'object' ? z.record(z.string(), z.any()) : z.string()
      if (spec.description) field = field.describe(spec.description)
      shape[name] = spec.required ? field : field.optional()
    }
    server.registerTool(
      tool.name,
      {
        title: tool.name,
        description: `${tool.description}${tool.write ? ' [write — requires BIGBUCK_MCP_ALLOW_WRITES=true]' : ''}`,
        inputSchema: shape,
        annotations: tool.write ? { readOnlyHint: false, destructiveHint: true, openWorldHint: true } : { readOnlyHint: true, openWorldHint: true },
      },
      async (args) => {
        try {
          return respond(await callGraphql(cfg, tool.document, args as Record<string, unknown>))
        } catch (error) {
          return failure(error)
        }
      },
    )
  }

  server.registerTool(
    'graphql_query',
    {
      title: 'graphql_query',
      description:
        'Run a GraphQL document against Big Buck (schema: schema.graphql in the repo). Select only the fields you need. ' +
        'Mutations return userErrors to act on and require BIGBUCK_MCP_ALLOW_WRITES=true.',
      inputSchema: { query: z.string(), variables: z.record(z.string(), z.any()).optional() },
      annotations: { readOnlyHint: false, openWorldHint: true },
    },
    async ({ query, variables }) => {
      try {
        return respond(await callGraphql(cfg, query, variables ?? {}))
      } catch (error) {
        return failure(error)
      }
    },
  )

  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
