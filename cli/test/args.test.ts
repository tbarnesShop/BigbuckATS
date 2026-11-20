import assert from 'node:assert/strict'
import { test } from 'node:test'

import { flagBool, flagString, parseArgs } from '../src/args.ts'

test('parseArgs splits command, flags, and positionals', () => {
  const parsed = parseArgs([
    'node',
    'bigbuck',
    'person',
    'create',
    '--name',
    'Ada',
    '--json',
    'extra',
  ])
  assert.deepEqual(parsed.command, ['person', 'create'])
  assert.equal(flagString(parsed.flags, 'name'), 'Ada')
  assert.equal(flagBool(parsed.flags, 'json'), true)
  assert.deepEqual(parsed.positionals, ['extra'])
})
