/**
 * Fails when schema.graphql removes or changes something clients rely on,
 * compared with a base version (decision 13: evolve additively, deprecate
 * before removing; no /v2).
 *
 *   node --import remix/node-tsx scripts/schema-breaking.ts <base schema file>
 *
 * A field may be removed once it has carried @deprecated in a released schema;
 * those removals are reported but allowed.
 */
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildSchema, findBreakingChanges, isObjectType, isInterfaceType, isInputObjectType, type GraphQLSchema } from 'graphql'

const here = dirname(fileURLToPath(import.meta.url))
const basePath = process.argv[2]
const currentPath = join(here, '..', '..', 'schema.graphql')

if (!basePath || !existsSync(basePath) || readFileSync(basePath, 'utf8').trim() === '') {
  console.log('No base schema.graphql to compare with; skipping the breaking-change check.')
  process.exit(0)
}

const base = buildSchema(readFileSync(basePath, 'utf8'))
const current = buildSchema(readFileSync(currentPath, 'utf8'))

function deprecatedFields(schema: GraphQLSchema): Set<string> {
  const out = new Set<string>()
  for (const type of Object.values(schema.getTypeMap())) {
    if (type.name.startsWith('__')) continue
    if (isObjectType(type) || isInterfaceType(type) || isInputObjectType(type)) {
      for (const field of Object.values(type.getFields())) {
        if (field.deprecationReason) out.add(`${type.name}.${field.name}`)
      }
    }
  }
  return out
}

const deprecated = deprecatedFields(base)
const changes = findBreakingChanges(base, current)
const allowed = changes.filter((c) => c.type === 'FIELD_REMOVED' && deprecated.has(c.description.split(' ')[0] ?? ''))
const breaking = changes.filter((c) => !allowed.includes(c))

for (const c of allowed) console.log(`allowed (was deprecated): ${c.description}`)
if (breaking.length === 0) {
  console.log(`schema.graphql: no breaking changes (${changes.length - breaking.length} allowed removals).`)
  process.exit(0)
}
console.error('Breaking GraphQL changes. Deprecate first (@deprecated), remove in a later release:')
for (const c of breaking) console.error(`  - ${c.type}: ${c.description}`)
process.exit(1)
