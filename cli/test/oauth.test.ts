import assert from 'node:assert/strict'
import { createHash, generateKeyPairSync, sign } from 'node:crypto'
import { mkdtemp, readdir, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { request } from 'node:http'
import { test } from 'node:test'
import * as oidc from 'openid-client'
import { accessToken, keychainAccount, login, logout, loopbackReceiver, serviceTokenProvider,
  sessionLock, settingsFromEnv, type StoredTokens, type TokenStore } from '../src/oauth.ts'

const settings = settingsFromEnv(undefined, { BIGBUCK_OAUTH_ISSUER: 'https://identity.example.test/',
  BIGBUCK_OAUTH_CLIENT_ID: 'native-cli', BIGBUCK_API_URL: 'https://api.example.test', BIGBUCK_OAUTH_AUDIENCE: 'bigbuck-api' })
const pair = generateKeyPairSync('rsa', { modulusLength: 2048 })
const jwk = { ...pair.publicKey.export({ format: 'jwk' }), kid: 'key-1', use: 'sig', alg: 'RS256' }
function signed(claims: Record<string, unknown>, badSignature = false): string {
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const body = `${encode({ alg: 'RS256', kid: 'key-1' })}.${encode(claims)}`
  const signature = sign('RSA-SHA256', Buffer.from(body), pair.privateKey)
  if (badSignature) signature[0] ^= 1
  return `${body}.${signature.toString('base64url')}`
}
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { 'content-type': 'application/json' },
})
function configuration(handler: (body: URLSearchParams, url: string, headers: Headers) => Response, secret?: string) {
  const config = new oidc.Configuration({ issuer: settings.issuer, authorization_endpoint: `${settings.issuer}authorize`,
    token_endpoint: `${settings.issuer}token`, jwks_uri: `${settings.issuer}keys`, revocation_endpoint: `${settings.issuer}revoke` },
  settings.clientId, {}, secret ? oidc.ClientSecretBasic(secret) : oidc.None())
  oidc.enableNonRepudiationChecks(config)
  config[oidc.customFetch] = async (url, options) => {
    if (String(url).endsWith('/keys')) return json({ keys: [jwk] })
    return handler(new URLSearchParams(options?.body as string), String(url), new Headers(options?.headers))
  }
  return config
}
function memory(initial: StoredTokens | null = null): TokenStore & { value: StoredTokens | null; writes: number } {
  let queue = Promise.resolve()
  return { value: initial, writes: 0,
    async read() { return this.value }, async write(value) { this.value = value; this.writes++ }, async clear() { this.value = null },
    async locked<T>(work: () => Promise<T>): Promise<T> {
      const previous = queue
      let release!: () => void
      queue = new Promise<void>(resolve => { release = resolve })
      await previous
      try { return await work() } finally { release() }
    },
  }
}

test('OAuth settings reject insecure endpoints and bind sessions to API and client', () => {
  assert.throws(() => settingsFromEnv(undefined, { BIGBUCK_OAUTH_ISSUER: 'http://evil.test', BIGBUCK_OAUTH_CLIENT_ID: 'cli' }), /HTTPS/)
  for (const api of ['http://localhost:3000', 'https://user:pass@api.test', 'https://api.test?token=x']) {
    assert.throws(() => settingsFromEnv(api, { BIGBUCK_OAUTH_ISSUER: settings.issuer, BIGBUCK_OAUTH_CLIENT_ID: 'cli' }))
  }
  assert.notEqual(keychainAccount(settings), keychainAccount({ ...settings, apiUrl: 'https://other.test' }))
  assert.notEqual(keychainAccount(settings), keychainAccount({ ...settings, clientId: 'other-cli' }))
})

test('loopback callback rejects incorrect state, duplicate state and Host', async () => {
  const receiver = await loopbackReceiver(0, 5000)
  receiver.expectState('secret-state')
  try {
    for (const query of ['state=wrong', 'state=secret-state&state=secret-state']) {
      assert.equal((await fetch(`${receiver.redirectUri}?${query}`)).status, 400)
    }
    const wrongHostStatus = await new Promise<number | undefined>((resolve, reject) => {
      const req = request(`${receiver.redirectUri}?state=secret-state`, { headers: { Host: 'evil.test' } }, res => {
        res.resume(); resolve(res.statusCode)
      })
      req.on('error', reject); req.end()
    })
    assert.equal(wrongHostStatus, 400)
    assert.equal((await fetch(`${receiver.redirectUri}?state=secret-state&code=valid`)).status, 200)
    assert.equal((await receiver.callback).searchParams.get('code'), 'valid')
  } finally { receiver.close() }
})

for (const scenario of ['success', 'nonce', 'signature', 'api-denied'] as const) {
  test(`authorization code + PKCE login: ${scenario}`, async () => {
    const store = memory()
    let authorization!: URL
    let exchanges = 0
    const config = configuration(body => {
      exchanges++
      assert.equal(body.get('grant_type'), 'authorization_code')
      assert.equal(body.get('redirect_uri'), authorization.searchParams.get('redirect_uri'))
      assert.equal(createHash('sha256').update(body.get('code_verifier')!).digest('base64url'), authorization.searchParams.get('code_challenge'))
      const now = Math.floor(Date.now() / 1000)
      return json({ access_token: 'api-access', refresh_token: 'refresh-1', token_type: 'Bearer', expires_in: 600,
        id_token: signed({ iss: settings.issuer, aud: settings.clientId, sub: 'person-1', iat: now, exp: now + 600,
          nonce: scenario === 'nonce' ? 'wrong-nonce' : authorization.searchParams.get('nonce') }, scenario === 'signature') })
    })
    let verifications = 0
    const work = login(settings, store, { config, async open(url) {
      authorization = new URL(url)
      assert.equal(authorization.searchParams.get('code_challenge_method'), 'S256')
      assert.ok(authorization.searchParams.get('nonce'))
      assert.equal(authorization.searchParams.get('audience'), 'bigbuck-api')
      const callback = new URL(authorization.searchParams.get('redirect_uri')!)
      callback.searchParams.set('state', authorization.searchParams.get('state')!)
      callback.searchParams.set('code', 'one-use-code')
      assert.equal((await fetch(callback)).status, 200)
    }, async verify(_settings, token) {
      verifications++
      assert.equal(token, 'api-access')
      if (scenario === 'api-denied') throw new Error('API denied')
      return { user: 'person-1' }
    } })
    if (scenario === 'success') {
      assert.deepEqual(await work, { user: 'person-1' })
      assert.equal(store.value?.refreshToken, 'refresh-1')
      assert.equal(store.value?.subject, 'person-1')
      assert.equal(store.writes, 1)
    } else {
      await assert.rejects(work)
      assert.equal(store.value, null)
      assert.equal(verifications, scenario === 'api-denied' ? 1 : 0)
    }
    assert.equal(exchanges, 1)
  })
}

test('refresh rotates tokens once under concurrency and stores before reuse', async t => {
  t.mock.method(globalThis, 'fetch', async () => json({ user: 'person-1' }))
  const store = memory({ accessToken: 'expired', refreshToken: 'refresh-1', expiresAt: 0, subject: 'person-1' })
  let grants = 0
  const config = configuration(body => {
    grants++
    assert.equal(body.get('grant_type'), 'refresh_token')
    assert.equal(body.get('refresh_token'), 'refresh-1')
    return json({ access_token: 'renewed', refresh_token: 'refresh-2', token_type: 'Bearer', expires_in: 600 })
  })
  assert.deepEqual(await Promise.all([accessToken(settings, store, config), accessToken(settings, store, config)]), ['renewed', 'renewed'])
  assert.equal(grants, 1)
  assert.equal(store.value?.refreshToken, 'refresh-2')
  assert.equal(store.writes, 1)
})

test('invalid_grant removes the unusable local session', async () => {
  const store = memory({ accessToken: 'expired', refreshToken: 'revoked', expiresAt: 0 })
  await assert.rejects(accessToken(settings, store, configuration(() => json({ error: 'invalid_grant' }, 400))), /renewal failed/)
  assert.equal(store.value, null)
})

test('logout revokes refresh and access tokens, always clears local credentials', async () => {
  for (const failure of [false, true]) {
    const store = memory({ accessToken: 'access', refreshToken: 'refresh', expiresAt: Date.now() + 600_000 })
    const revoked: string[] = []
    const work = logout(settings, store, configuration(body => {
      revoked.push(body.get('token')!)
      return failure ? json({ error: 'server_error' }, 500) : new Response(null, { status: 200 })
    }))
    if (failure) await assert.rejects(work, /Local session removed/)
    else { await work; assert.deepEqual(revoked, ['refresh', 'access']) }
    assert.equal(store.value, null)
  }
})

test('machine credentials request API scopes and cache short-lived tokens without a human session', async () => {
  let grants = 0
  const config = configuration((body, _url, headers) => {
    grants++
    const authorization = headers.get('authorization')!
    assert.ok(authorization.startsWith('Basic '))
    const encoded = Buffer.from(authorization.slice(6), 'base64').toString().split(':')
    assert.deepEqual(encoded.map(value => decodeURIComponent(value)), ['native-cli', 'machine-secret'])
    assert.equal(body.has('client_secret'), false)
    assert.equal(body.get('grant_type'), 'client_credentials')
    assert.equal(body.get('scope'), settings.scopes)
    assert.equal(body.get('audience'), settings.audience)
    return json({ access_token: 'machine-token', token_type: 'Bearer', expires_in: 600 })
  }, 'machine-secret')
  const get = serviceTokenProvider(settings, 'machine-secret', config)
  assert.deepEqual(await Promise.all([get(), get()]), ['machine-token', 'machine-token'])
  assert.equal(await get(), 'machine-token')
  assert.equal(grants, 1)
  const bad = serviceTokenProvider(settings, 'secret', configuration(() => json({ access_token: 'long-lived', token_type: 'Bearer', expires_in: 3600 })))
  await assert.rejects(bad(), /15 minutes/)
})

test('filesystem session lock serializes rotation and writes no credentials', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'bigbuck-oauth-lock-'))
  const account = keychainAccount(settings)
  let active = 0
  try {
    await Promise.all(Array.from({ length: 3 }, () => sessionLock(account, async () => {
      assert.equal(active++, 0)
      await new Promise(resolve => setTimeout(resolve, 25))
      active--
    }, directory)))
    const files = await readdir(directory)
    assert.deepEqual(files, [`${account}.session`])
    assert.equal(await readFile(join(directory, files[0]), 'utf8'), '')
  } finally { await rm(directory, { recursive: true, force: true }) }
})
