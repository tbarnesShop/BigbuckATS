import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'

import { ALL_SCOPE_KEYS, grantableScopes } from './scopes.ts'

const here = dirname(fileURLToPath(import.meta.url))
const rails = readFileSync(join(here, '..', '..', '..', 'app', 'services', 'scopes.rb'), 'utf8')
const railsKeys = [...rails.matchAll(/^\s+"([a-z_]+:[a-z_]+)" =>/gm)].map((match) => match[1])

describe('scopes', () => {
  it('the picker offers exactly the scopes Rails accepts', () => {
    assert.deepEqual([...ALL_SCOPE_KEYS].sort(), [...railsKeys].sort())
  })

  it('only offers scopes the member role backs', () => {
    const keys = grantableScopes(['person.read', 'job.read']).flatMap((group) =>
      group.scopes.map((scope) => scope.key),
    )
    assert.deepEqual(keys.sort(), ['jobs:read', 'people:read'])
  })
})
