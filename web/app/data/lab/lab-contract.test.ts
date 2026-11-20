import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'
import { hasStructuredErrors, parseCommand } from './runners.ts'
import { apiCatalog } from './catalog.ts'
import { article, reference } from '../docs.ts'
import { mkdtempSync, readdirSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { readLabCredentials, storeLabCredentials } from './credentials.ts'

describe('lab execution boundaries and published references', () => {
  it('seals runner credentials for the cookie when there is no shared disk (Vercel)', () => {
    const saved = { store: process.env.LAB_CREDENTIAL_STORE, secret: process.env.SESSION_SECRET }
    process.env.LAB_CREDENTIAL_STORE = 'cookie'
    process.env.SESSION_SECRET = 'test-session-secret-at-least-32-characters'
    try {
      const credentials = {
        toolToken: 'sample-api',
        agentToken: 'sample-agent',
        expiresAt: new Date(Date.now() + 60000).toISOString(),
      }
      const sealed = storeLabCredentials(credentials)
      assert.ok(sealed.startsWith('sealed.'))
      assert.equal(sealed.includes('sample-api'), false, 'tokens are not readable in the reference')
      assert.deepEqual(readLabCredentials(sealed), credentials)
      const tampered = sealed.slice(0, -2) + (sealed.endsWith('A') ? 'B' : 'A') + sealed.slice(-1)
      assert.equal(readLabCredentials(tampered), null)
      const expired = storeLabCredentials({ ...credentials, expiresAt: new Date(0).toISOString() })
      assert.equal(readLabCredentials(expired), null)
      process.env.SESSION_SECRET = 'a-different-secret-of-at-least-32-chars'
      assert.equal(readLabCredentials(sealed), null, 'another secret cannot open it')
    } finally {
      for (const [key, value] of [
        ['LAB_CREDENTIAL_STORE', saved.store],
        ['SESSION_SECRET', saved.secret],
      ] as const) {
        if (value === undefined) delete process.env[key]
        else process.env[key] = value
      }
    }
  })

  it('keeps runner credentials in private expiring server files with opaque references', () => {
    const previous = process.env.LAB_CREDENTIAL_DIR
    const directory = mkdtempSync(join(tmpdir(), 'bigbuck-credentials-'))
    process.env.LAB_CREDENTIAL_DIR = directory
    try {
      const credentials = {
        toolToken: 'sample-api',
        agentToken: 'sample-agent',
        expiresAt: new Date(Date.now() + 60000).toISOString(),
      }
      const key = storeLabCredentials(credentials)
      assert.match(key, /^[a-f0-9]{48}$/)
      assert.deepEqual(readLabCredentials(key), credentials)
      assert.equal(statSync(join(directory, `${key}.json`)).mode & 0o777, 0o600)
      assert.equal(readLabCredentials('../../elsewhere'), null)
      const expired = storeLabCredentials({ ...credentials, expiresAt: new Date(0).toISOString() })
      assert.equal(readLabCredentials(expired), null)
      assert.equal(readdirSync(directory).includes(`${expired}.json`), false)
    } finally {
      if (previous === undefined) delete process.env.LAB_CREDENTIAL_DIR
      else process.env.LAB_CREDENTIAL_DIR = previous
      rmSync(directory, { recursive: true, force: true })
    }
  })
  it('distinguishes empty GraphQL errors from real failures without altering HTTP status', () => {
    assert.equal(hasStructuredErrors({ data: { createPerson: { userErrors: [] } }, errors: [] }), false)
    assert.equal(
      hasStructuredErrors({ data: { createPerson: { userErrors: [{ code: 'forbidden' }] } } }),
      true,
    )
    assert.equal(hasStructuredErrors({ errors: [{ message: 'Invalid input' }] }), true)
    assert.equal(hasStructuredErrors({ description: '"userErrors":[{ is only text' }), false)
  })
  it('parses literal CLI arguments without invoking a general shell', () => {
    assert.deepEqual(parseCommand('bigbuck project create --name "A future team"'), [
      'project',
      'create',
      '--name',
      'A future team',
    ])
    assert.deepEqual(parseCommand('bigbuck api list --q people'), ['api', 'list', '--q', 'people'])
    assert.deepEqual(parseCommand('bigbuck api listPeople'), ['api', 'listPeople'])
    assert.deepEqual(parseCommand('bigbuck gql whoami'), ['gql', 'whoami'])
    assert.deepEqual(parseCommand('bigbuck gql person --id abc'), ['gql', 'person', '--id', 'abc'])
    for (const input of [
      'sh -c whoami',
      'curl example.test',
      'bigbuck person list --token=escape',
      'bigbuck whoami --api-url http://elsewhere',
      'bigbuck person create --name "unclosed',
      'bigbuck agent list',
      'bigbuck api createAgent --body "{}"',
    ]) {
      assert.throws(() => parseCommand(input))
    }
  })
  it('keeps identity and public-token operations out of the browser executor', () => {
    for (const name of [
      'createOrganization',
      'createCredential',
      'createAgent',
      'createSession',
      'acceptPublicOffer',
    ])
      assert.equal(apiCatalog().find((op) => op.name === name)?.available, false)
    assert.equal(apiCatalog().find((op) => op.name === 'createPerson')?.available, true)
  })
  it('publishes current schemas, actual command help, and safe preparation links', () => {
    assert.match(reference('rest')!.html, /createPerson/)
    assert.match(reference('graphql')!.html, /type Query/)
    assert.match(reference('cli')!.html, /bigbuck config plan/)
    assert.match(reference('cli')!.html, /bigbuck api &lt;operationId&gt;/)
    assert.match(reference('cli')!.html, /bigbuck gql whoami/)
    assert.match(reference('mcp')!.html, /graphql_query/)
    assert.match(article('agents')!.html, /surface=mcp&amp;operation=gql_whoami/)
    assert.match(article('start')!.html, /OpenAPI contract/)
    assert.match(article('interop')!.html, /bigbuck api/)
    assert.match(article('interop')!.html, /bigbuck gql/)
    assert.equal(article('../secrets'), null)
  })
})
