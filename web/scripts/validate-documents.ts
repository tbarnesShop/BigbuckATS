/**
 * Validates every GraphQL document we ship against schema.graphql: the web
 * app's operations and the MCP server's curated agent tools.
 */
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildSchema, parse, validate } from 'graphql'

import { operations } from '../app/graphql/operations.ts'
import { CURATED_TOOLS } from '../../sdk/src/curated-graphql.ts'

const here = dirname(fileURLToPath(import.meta.url))
const schema = buildSchema(readFileSync(join(here, '..', '..', 'schema.graphql'), 'utf8'))

const documents: Array<[string, string]> = [
  ...Object.entries(operations).map(([name, doc]): [string, string] => [`web:${name}`, doc]),
  ...CURATED_TOOLS.map((tool): [string, string] => [`mcp:${tool.name}`, tool.document]),
]

let failed = 0
for (const [name, doc] of documents) {
  const errors = validate(schema, parse(doc))
  if (errors.length) {
    failed++
    console.error(`${name}:\n${errors.map((e) => `  - ${e.message}`).join('\n')}`)
  }
}
if (failed) process.exit(1)
console.log(`${documents.length} GraphQL documents are valid against schema.graphql.`)
