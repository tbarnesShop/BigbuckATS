import assert from 'node:assert/strict'
import { test } from 'node:test'

import { loadOperations } from '../src/openapi.ts'

test('OpenAPI yields MCP tool operations with unique ids', () => {
  const ops = loadOperations()
  assert.ok(ops.length >= 30, `expected many operations, got ${ops.length}`)
  const ids = ops.map((o) => o.operationId)
  assert.equal(new Set(ids).size, ids.length)
  assert.ok(ids.includes('listPeople'))
  assert.ok(ids.includes('listProjects'))
  assert.ok(ids.includes('listSequences'))
  assert.ok(ids.includes('enrollInSequence'))
  assert.ok(ids.includes('convertProjectMember'))
  assert.ok(ids.includes('createScorecard'))
  assert.ok(ids.includes('listEvents'))
})

test('write ops are marked for mutation gating', () => {
  const ops = loadOperations()
  const list = ops.find((o) => o.operationId === 'listPeople')
  const create = ops.find((o) => o.operationId === 'createPerson')
  assert.equal(list?.write, false)
  assert.equal(create?.write, true)
})
