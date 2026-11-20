import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { test } from 'node:test'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const cli = resolve(root, 'src/cli.ts')

function run(args: string[]) {
  return spawnSync(process.execPath, ['--import', 'tsx', cli, ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { ...process.env, BIGBUCK_TOKEN: 'bb_live_test' },
  })
}

test('help documents api, agent, and graphql surfaces', () => {
  const result = run(['help'])
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /bigbuck api list/)
  assert.match(result.stdout, /bigbuck api <operationId>/)
  assert.match(result.stdout, /bigbuck agent list/)
  assert.match(result.stdout, /bigbuck gql whoami/)
  assert.match(result.stdout, /bigbuck gql query/)
})

test('api list prints OpenAPI operationIds without calling the network', () => {
  const result = run(['api', 'list', '--q', 'listPeople', '--json'])
  assert.equal(result.status, 0, result.stderr)
  const payload = JSON.parse(result.stdout) as { data: Array<{ operationId: string; path: string }> }
  assert.ok(payload.data.some((row) => row.operationId === 'listPeople' && row.path === '/people'))
})

test('gql list prints curated GraphQL tools without calling the network', () => {
  const result = run(['gql', 'list', '--json'])
  assert.equal(result.status, 0, result.stderr)
  const payload = JSON.parse(result.stdout) as { data: Array<{ name: string }> }
  assert.ok(payload.data.some((row) => row.name === 'gql_whoami'))
  assert.ok(payload.data.some((row) => row.name === 'gql_person'))
})
