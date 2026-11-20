import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'

import { persistedManifest } from './graphql.ts'

const here = dirname(fileURLToPath(import.meta.url))
const committed = JSON.parse(
  readFileSync(join(here, '..', '..', '..', 'app', 'graphql', 'persisted_queries.json'), 'utf8'),
) as Record<string, string>

describe('persisted GraphQL queries', () => {
  it('match app/graphql/operations.ts exactly (run pnpm persist-queries after editing or formatting it)', () => {
    // Rails only runs registered documents, so any change to a query's text, even formatting, must be re-registered.
    assert.deepEqual(Object.keys(persistedManifest()).sort(), Object.keys(committed).sort())
  })
})
