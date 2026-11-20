import assert from 'node:assert/strict'
import * as http from 'node:http'
import { test } from 'node:test'

import { BigBuckApiError, BigBuckClient } from '../src/index.ts'

test('client sends tenant, actor, and idempotency headers on writes', async () => {
  const seen: { method?: string; headers?: http.IncomingHttpHeaders; url?: string; body?: string } =
    {}
  const server = http.createServer((req, res) => {
    seen.method = req.method
    seen.headers = req.headers
    seen.url = req.url
    let raw = ''
    req.on('data', (c) => {
      raw += c
    })
    req.on('end', () => {
      seen.body = raw
      res.statusCode = 201
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify({ id: 'p1', display_name: 'Ada' }))
    })
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }

  const client = new BigBuckClient({
    baseUrl: `http://127.0.0.1:${port}`,
    organizationId: 'org-1',
    actorId: 'user-1',
  })
  const person = await client.createPerson({ display_name: 'Ada', email: 'ada@x.test' })
  assert.equal(person.id, 'p1')
  assert.equal(seen.method, 'POST')
  assert.equal(seen.url, '/v1/people')
  assert.equal(seen.headers?.['x-organization-id'], 'org-1')
  assert.equal(seen.headers?.['x-actor-id'], 'user-1')
  assert.equal(seen.headers?.['x-actor-type'], 'cli')
  assert.ok(String(seen.headers?.['idempotency-key'] ?? '').startsWith('sdk-'))
  assert.match(seen.body ?? '', /display_name/)

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('client raises BigBuckApiError on problem+json', async () => {
  const server = http.createServer((_req, res) => {
    res.statusCode = 401
    res.setHeader('Content-Type', 'application/problem+json')
    res.end(
      JSON.stringify({
        type: 'about:blank',
        title: 'X-Organization-Id required',
        status: 401,
        code: 'tenant_required',
        request_id: 'req-1',
      }),
    )
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }

  const client = new BigBuckClient({
    baseUrl: `http://127.0.0.1:${port}`,
    organizationId: 'org-1',
  })
  await assert.rejects(() => client.listPeople(), (err: unknown) => {
    assert.ok(err instanceof BigBuckApiError)
    assert.equal(err.status, 401)
    assert.equal(err.code, 'tenant_required')
    assert.equal(err.requestId, 'req-1')
    return true
  })

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('config plan and import payloads match API shape', async () => {
  const bodies: unknown[] = []
  const server = http.createServer((req, res) => {
    let raw = ''
    req.on('data', (c) => {
      raw += c
    })
    req.on('end', () => {
      bodies.push(JSON.parse(raw || '{}'))
      res.statusCode = 201
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify({ id: 'x1', status: 'open' }))
    })
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }
  const client = new BigBuckClient({
    baseUrl: `http://127.0.0.1:${port}`,
    organizationId: 'org-1',
  })

  await client.createConfigPlan([{ kind: 'PipelineTemplate', key: 'eng', spec: { name: 'Eng' } }])
  await client.createImport({
    csv: 'name,email\nA,a@t.test\n',
    dryRun: true,
    fieldMapping: { name: 'display_name', email: 'primary_email' },
  })

  assert.deepEqual(bodies[0], {
    documents: [{ kind: 'PipelineTemplate', key: 'eng', spec: { name: 'Eng' } }],
  })
  assert.deepEqual(bodies[1], {
    import: {
      entity: 'people',
      csv: 'name,email\nA,a@t.test\n',
      dry_run: true,
      source_system: 'csv',
      field_mapping: { name: 'display_name', email: 'primary_email' },
    },
  })

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('a token client sends Authorization and the surface, not legacy tenant headers', async () => {
  let headers: http.IncomingHttpHeaders = {}
  const server = http.createServer((req, res) => {
    headers = req.headers
    res.statusCode = 200
    res.setHeader('Content-Type', 'application/json')
    res.end(JSON.stringify({ data: [] }))
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }

  const client = new BigBuckClient({ baseUrl: `http://127.0.0.1:${port}`, token: 'bb_live_tok', actAsAgentId: 'agent-1' })
  await client.listAgents()
  assert.equal(headers.authorization, 'Bearer bb_live_tok')
  assert.equal(headers['x-bigbuck-surface'], 'cli')
  assert.equal(headers['x-bigbuck-act-as-agent'], 'agent-1')
  assert.equal(headers['x-organization-id'], undefined)
  assert.equal(headers['x-actor-id'], undefined)

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('a client needs a token or the legacy organization id', () => {
  assert.throws(() => new BigBuckClient({ baseUrl: 'http://x' }), /token is required/)
})

test('graphql posts documents to /graphql with surface headers', async () => {
  const seen: { url?: string; headers?: http.IncomingHttpHeaders; body?: string } = {}
  const server = http.createServer((req, res) => {
    seen.url = req.url
    seen.headers = req.headers
    let raw = ''
    req.on('data', (c) => {
      raw += c
    })
    req.on('end', () => {
      seen.body = raw
      res.statusCode = 200
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify({ data: { viewer: { roleKey: 'owner' } } }))
    })
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }
  const client = new BigBuckClient({
    baseUrl: `http://127.0.0.1:${port}`,
    token: 'bb_live_tok',
  })

  const body = await client.curatedGraphql<{ data: { viewer: { roleKey: string } } }>('gql_whoami')
  assert.equal(body.data.viewer.roleKey, 'owner')
  assert.equal(seen.url, '/graphql')
  assert.equal(seen.headers?.authorization, 'Bearer bb_live_tok')
  assert.equal(seen.headers?.['x-bigbuck-surface'], 'cli')
  assert.match(seen.body ?? '', /viewer/)

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('invoke resolves OpenAPI operationIds onto /v1 paths', async () => {
  const seen: { method?: string; url?: string; body?: string } = {}
  const server = http.createServer((req, res) => {
    seen.method = req.method
    seen.url = req.url
    let raw = ''
    req.on('data', (c) => {
      raw += c
    })
    req.on('end', () => {
      seen.body = raw
      res.statusCode = 200
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify({ data: [] }))
    })
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }
  const client = new BigBuckClient({
    baseUrl: `http://127.0.0.1:${port}`,
    organizationId: 'org-1',
  })

  assert.ok(client.listOperations().some((op) => op.operationId === 'listPeople'))
  await client.invoke('listPeople', { q: 'Ava' })
  assert.equal(seen.method, 'GET')
  assert.equal(seen.url, '/v1/people?q=Ava')

  await client.invoke('createDncCompany', {
    body: { dnc_company: { domain: 'blocked.test' } },
  })
  assert.equal(seen.method, 'POST')
  assert.equal(seen.url, '/v1/dnc_companies')
  assert.match(seen.body ?? '', /blocked\.test/)

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('token providers renew each request and never fall back to legacy headers', async () => {
  let calls = 0
  const seen: Headers[] = []
  const client = BigBuckClient.fromEnv({ baseUrl: 'https://api.example.test', organizationId: 'legacy-org',
    tokenProvider: async () => ++calls < 3 ? `access-${calls}` : '',
    fetch: async (_url, init) => {
      seen.push(new Headers(init?.headers))
      assert.equal(init?.redirect, 'error')
      return new Response('{"data":[]}', { headers: { 'content-type': 'application/json' } })
    },
  })
  await client.listPeople()
  await client.listPeople()
  await assert.rejects(client.listPeople(), /empty token/)
  assert.deepEqual(seen.map(h => h.get('authorization')), ['Bearer access-1', 'Bearer access-2'])
  assert.ok(seen.every(h => !h.has('x-organization-id')))
})
