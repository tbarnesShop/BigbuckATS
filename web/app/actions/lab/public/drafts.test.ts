import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'
import { Drafts, draftKey, type RawDraft, memoryOnly } from './drafts.ts'
function storage() {
  const data = new Map<string, string>()
  return {
    data,
    getItem: (key: string) => data.get(key) ?? null,
    setItem: (key: string, value: string) => {
      data.set(key, value)
    },
    removeItem: (key: string) => {
      data.delete(key)
    },
    key: (i: number) => [...data.keys()][i] ?? null,
    get length() {
      return data.size
    },
  }
}
const scope = { organization: 'org-a', sandbox: 'cli', persona: 'user-a', generation: 3, surface: 'api' }
const raw: RawDraft = {
  fields: { body: ' {\n  "person": BROKEN,\n\n ' },
  command: 'bigbuck person list  ',
  edited: true,
  recover: true,
}
describe('lab draft ownership and recovery', () => {
  it('recovers exact malformed text and isolates every identity boundary and schema', () => {
    const tab = storage(),
      drafts = new Drafts(tab),
      key = draftKey(scope, 'createPerson', { version: 1 })
    drafts.save(key, raw)
    assert.deepEqual(new Drafts(tab).read(key), raw)
    for (const different of [
      { ...scope, organization: 'org-b' },
      { ...scope, sandbox: 'api' },
      { ...scope, persona: 'user-b' },
      { ...scope, generation: 4 },
      { ...scope, surface: 'mcp' },
    ])
      assert.equal(new Drafts(tab).read(draftKey(different, 'createPerson', { version: 1 })), undefined)
    assert.equal(new Drafts(tab).read(draftKey(scope, 'listPeople', { version: 1 })), undefined)
    assert.equal(new Drafts(tab).read(draftKey(scope, 'createPerson', { version: 2 })), undefined)
  })
  it('requires sample consent and removes stored drafts when credentials appear, even in malformed input', () => {
    const tab = storage(),
      drafts = new Drafts(tab),
      key = draftKey(scope, 'createPerson', 1)
    drafts.save(key, { ...raw, recover: false })
    assert.equal(tab.length, 0)
    drafts.save(key, raw)
    const secret = { ...raw, fields: { body: '{ "api_key": "synthetic-test-value" BROKEN' } }
    assert.equal(memoryOnly(secret), true)
    assert.equal(drafts.save(key, secret), false)
    assert.equal(tab.length, 0)
    assert.deepEqual(drafts.read(key), secret)
    assert.equal(drafts.unrecovered().length, 1)
    assert.equal(memoryOnly({ ...raw, command: 'bigbuck config --token synthetic-test-value' }), true)
  })
  it('keeps drafts recoverable in memory when storage throws and rejects malformed stored envelopes', () => {
    const tab = storage(),
      key = draftKey(scope, 'createPerson', 1)
    const denied = new Drafts({
      ...tab,
      setItem() {
        throw new Error('QuotaExceededError')
      },
    })
    assert.equal(denied.save(key, raw), false)
    assert.deepEqual(denied.read(key), raw)
    assert.equal(denied.unrecovered().length, 1)
    tab.setItem(key, JSON.stringify({ fields: { body: {} }, command: '', edited: true, recover: true }))
    assert.equal(new Drafts(tab).read(key), undefined)
    assert.equal(tab.length, 0)
  })
  it('discards only memory-only work, while sign-out clears all lab drafts and preserves unrelated storage', () => {
    const tab = storage(),
      drafts = new Drafts(tab)
    const one = draftKey(scope, 'createPerson', 1),
      two = draftKey(scope, 'listPeople', 1)
    drafts.save(one, raw)
    drafts.save(two, { ...raw, recover: false })
    tab.setItem('unrelated', 'keep')
    drafts.discardUnrecovered()
    assert.equal(drafts.read(two), undefined)
    assert.deepEqual(drafts.read(one), raw)
    drafts.clear()
    assert.equal(drafts.read(one), undefined)
    assert.equal(tab.getItem('unrelated'), 'keep')
    assert.equal(tab.length, 1)
  })
})

import { validateInput } from './validation.ts'
it('checks required fields and parsed JSON shape only at execution, including nested objects', () => {
  const schema = {
    type: 'object',
    required: ['person'],
    properties: {
      person: {
        type: 'object',
        required: ['display_name'],
        properties: { display_name: { type: 'string' } },
      },
    },
  }
  validateInput({ person: { display_name: 'Sample' } }, schema)
  for (const value of [[], {}, { person: [] }, { person: { display_name: 123 } }]) {
    assert.throws(() => validateInput(value, schema), SyntaxError)
  }
})
