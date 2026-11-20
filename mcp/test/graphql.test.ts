import assert from 'node:assert/strict'
import * as http from 'node:http'
import { test } from 'node:test'

import { CURATED_TOOLS } from '../src/curated.ts'
import { callGraphql, isMutation } from '../src/graphql.ts'

test('isMutation spots mutations and ignores comments and field names', () => {
  assert.equal(isMutation('mutation { rejectApplication(input: {}) { userErrors { code } } }'), true)
  assert.equal(isMutation('  # mutation in a comment\n query { viewer { actorType } }'), false)
  assert.equal(isMutation('query { mutationLog { id } }'), false)
  assert.equal(isMutation('query A { viewer { id } } mutation B { x }'), true)
})

test('callGraphql sends the bearer token to /graphql and gates mutations', async () => {
  let seen: { url?: string; headers?: http.IncomingHttpHeaders; body?: string } = {}
  const server = http.createServer((req, res) => {
    const chunks: Buffer[] = []
    req.on('data', (c) => chunks.push(c))
    req.on('end', () => {
      seen = { url: req.url, headers: req.headers, body: Buffer.concat(chunks).toString('utf8') }
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify({ data: { viewer: { actorType: 'agent' } } }))
    })
  })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as { port: number }
  const cfg = { baseUrl: `http://127.0.0.1:${port}`, token: 'bb_live_tok', allowWrites: false }

  const result = await callGraphql(cfg, 'query { viewer { actorType } }')
  assert.equal(result.status, 200)
  assert.equal(seen.url, '/graphql')
  assert.equal(seen.headers?.authorization, 'Bearer bb_live_tok')
  assert.equal(seen.headers?.['x-bigbuck-surface'], 'mcp')
  assert.deepEqual(JSON.parse(seen.body ?? '{}').variables, {})

  await assert.rejects(() => callGraphql(cfg, 'mutation { x }'), /Mutations are disabled/)
  await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())))
})

test('curated tools are uniquely named and writes are mutations', () => {
  const names = CURATED_TOOLS.map((t) => t.name)
  assert.equal(new Set(names).size, names.length)
  for (const tool of CURATED_TOOLS) assert.equal(isMutation(tool.document), tool.write, tool.name)
})
