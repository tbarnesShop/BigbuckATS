/**
 * Registers the web app's GraphQL documents with Rails as persisted queries:
 * writes ../app/graphql/persisted_queries.json as { sha256: document }.
 * Browser sessions may only run documents in that file.
 */
import { writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { persistedManifest } from '../app/data/graphql.ts'

const here = dirname(fileURLToPath(import.meta.url))
const target = join(here, '..', '..', 'app', 'graphql', 'persisted_queries.json')
writeFileSync(target, `${JSON.stringify(persistedManifest(), null, 2)}\n`)
console.log(`Wrote ${Object.keys(persistedManifest()).length} persisted queries → ${target}`)
