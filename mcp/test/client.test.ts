import assert from 'node:assert/strict'
import * as http from 'node:http'
import { test } from 'node:test'

import { callApi } from '../src/client.ts'

test('callApi sends legacy tenant + agent headers without a token and blocks writes by default', async () => {
  const seen: { method?: string; headers?: http.IncomingHttpHeaders; url?: string } = {}
  const server = http.createServer((req, res) => {
    seen.method = req.method
    seen.headers = req.headers
    seen.url = req.url
    res.statusCode = 200
    res.setHeader('Content-Type', 'application/json')
    res.end(JSON.stringify({ data: [] }))
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }

  const cfg = {
    baseUrl: `http://127.0.0.1:${port}`,
    organizationId: 'org-1',
    actorId: 'user-1',
    allowWrites: false,
  }

  const read = await callApi(cfg, 'get', '/people', {}, { write: false, hasJsonBody: false })
  assert.equal(read.status, 200)
  assert.equal(seen.method, 'GET')
  assert.equal(seen.headers?.['x-organization-id'], 'org-1')
  assert.equal(seen.headers?.['x-actor-id'], 'user-1')
  assert.equal(seen.headers?.['x-actor-type'], 'agent')

  await assert.rejects(
    () => callApi(cfg, 'post', '/people', { body: { person: { display_name: 'A' } } }, { write: true, hasJsonBody: true }),
    /Write tools are disabled/,
  )

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('callApi substitutes path params and sends idempotency on writes', async () => {
  let path = ''
  let idem: string | undefined
  const server = http.createServer((req, res) => {
    path = req.url ?? ''
    idem = typeof req.headers['idempotency-key'] === 'string' ? req.headers['idempotency-key'] : undefined
    res.statusCode = 201
    res.end(JSON.stringify({ ok: true }))
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }

  const result = await callApi(
    {
      baseUrl: `http://127.0.0.1:${port}`,
      organizationId: 'org-1',
      allowWrites: true,
    },
    'post',
    '/projects/{id}/members',
    { id: 'proj-1', body: { member: { person_id: 'p1' } } },
    { write: true, hasJsonBody: true },
  )
  assert.equal(result.status, 201)
  assert.equal(path, '/v1/projects/proj-1/members')
  assert.ok(idem?.startsWith('mcp-'))

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('callApi sends the bearer token and no tenant headers when a token is set', async () => {
  let headers: http.IncomingHttpHeaders = {}
  const server = http.createServer((req, res) => {
    headers = req.headers
    res.statusCode = 200
    res.end(JSON.stringify({ data: [] }))
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }

  await callApi(
    { baseUrl: `http://127.0.0.1:${port}`, token: 'bb_live_abc', organizationId: 'org-1', allowWrites: false },
    'get',
    '/people',
    {},
    { write: false, hasJsonBody: false },
  )
  assert.equal(headers.authorization, 'Bearer bb_live_abc')
  assert.equal(headers['x-bigbuck-surface'], 'mcp')
  assert.equal(headers['x-organization-id'], undefined)
  assert.equal(headers['x-actor-id'], undefined)

  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})
