import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'

import { router } from '../router.ts'
import { routes } from '../routes.ts'
import { sessionCookie, sessionStorage } from '../data/auth.ts'
import { storeLabCredentials } from '../data/lab/credentials.ts'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

describe('root controller', () => {
  it('a lost server credential produces an explicit restart state', async () => {
    const session = await sessionStorage.read(null)
    session.set('token', 'sample-ui-session')
    session.set('lab', { surface: 'api', sandbox: 'api', generation: 1, credentialKey: '0'.repeat(48) })
    const value = await sessionStorage.save(session)
    if (value === null) throw new Error('Expected a changed session')
    const cookie = await sessionCookie.serialize(JSON.stringify({ value, expires: Date.now() + 60000 }))
    const response = await router.fetch(
      new Request('http://localhost/lab/inspect?kind=people&id=00000000-0000-0000-0000-000000000000', {
        headers: { Cookie: cookie.split(';')[0] },
      }),
    )
    assert.equal(response.status, 409)
    assert.equal((await response.json()).code, 'sandbox_expired')
  })
  it('lab polling and inspection request a persona when the session is missing', async () => {
    for (const path of ['/lab/status', '/lab/inspect?kind=people&id=00000000-0000-0000-0000-000000000000']) {
      const response = await router.fetch(new URL(path, 'http://localhost'))
      assert.equal(response.status, 401)
      assert.equal((await response.json()).code, 'lab_session_required')
    }
  })
  it('GET / opens the anonymous lab', async () => {
    let response = await router.fetch(new URL(routes.home.href(), 'http://localhost'))

    assert.equal(response.status, 303)
    assert.equal(response.headers.get('Location'), '/session')
  })

  it('GET /people without session shows setup', async () => {
    delete process.env.BIGBUCK_ORG_ID
    let response = await router.fetch(new URL(routes.peopleIndex.href(), 'http://localhost'))
    assert.equal(response.status, 200)
    assert.match(await response.text(), /Sign in to continue/)
  })

  it('GET /jobs without session shows setup', async () => {
    delete process.env.BIGBUCK_ORG_ID
    let response = await router.fetch(new URL(routes.jobsIndex.href(), 'http://localhost'))
    assert.equal(response.status, 200)
    assert.match(await response.text(), /Sign in to continue/)
  })

  it('GET /interviews and /offers without session show setup', async () => {
    delete process.env.BIGBUCK_ORG_ID
    for (const href of [
      routes.interviewsIndex.href(),
      routes.offersIndex.href(),
      routes.jobsCreate.index.href(),
    ]) {
      let response = await router.fetch(new URL(href, 'http://localhost'))
      assert.equal(response.status, 200)
      assert.match(await response.text(), /Sign in to continue/)
    }
  })

  it('legacy paths redirect without throwing on security headers', async () => {
    const expected: Record<string, string> = {
      '/pipeline': '/jobs',
      '/openings': routes.requisitions.index.href(),
      '/candidates': '/people',
      '/settings/workspace': '/settings',
    }
    for (const [from, to] of Object.entries(expected)) {
      const response = await router.fetch(new URL(`${from}?x=1`, 'http://localhost'))
      assert.equal(response.status, 302, from)
      assert.equal(response.headers.get('Location'), `http://localhost${to}?x=1`, from)
      assert.equal(response.headers.get('X-Content-Type-Options'), 'nosniff', from)
    }
  })

  it('GET /interviews/:id without session shows setup', async () => {
    delete process.env.BIGBUCK_ORG_ID
    const response = await router.fetch(
      new URL(routes.interviewsShow.href({ interviewId: 'interview-missing' }), 'http://localhost'),
    )
    assert.equal(response.status, 200)
    assert.match(await response.text(), /Sign in to continue/)
  })
})

describe('cross-origin protection', () => {
  it('rejects a cross-site form post', async () => {
    const response = await router.fetch(
      new Request('http://localhost/theme', {
        method: 'POST',
        headers: { 'Sec-Fetch-Site': 'cross-site', 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'theme=dark',
      }),
    )
    assert.equal(response.status, 403)
  })

  it('allows a same-origin form post', async () => {
    const response = await router.fetch(
      new Request('http://localhost/theme', {
        method: 'POST',
        headers: { 'Sec-Fetch-Site': 'same-origin', 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'theme=dark&return_to=/jobs',
      }),
    )
    assert.equal(response.status, 303)
    assert.equal(response.headers.get('Location'), '/jobs')
  })

  it('never redirects a theme change off-site', async () => {
    const response = await router.fetch(
      new Request('http://localhost/theme', {
        method: 'POST',
        headers: { 'Sec-Fetch-Site': 'same-origin', 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'theme=dark&return_to=//evil.example/x',
      }),
    )
    assert.equal(response.headers.get('Location'), '/')
  })
})

describe('lab server execution outcomes', () => {
  it('distinguishes upstream connection loss from preflight failure and retains a completed write if context refresh fails', async () => {
    const previousDirectory = process.env.LAB_CREDENTIAL_DIR
    const directory = mkdtempSync(join(tmpdir(), 'lab-outcome-test-'))
    process.env.LAB_CREDENTIAL_DIR = directory
    const originalFetch = globalThis.fetch
    try {
      const session = await sessionStorage.read(null)
      session.set('token', 'synthetic-ui-session')
      session.set('organizationId', 'fixture-org')
      session.set('userId', 'fixture-persona')
      session.set('lab', {
        surface: 'api',
        sandbox: 'api',
        generation: 1,
        mode: 'explore',
        runKey: 'fixture',
        resetsAt: '2099-01-01T00:00:00Z',
        credentialKey: storeLabCredentials({
          toolToken: 'synthetic-api',
          agentToken: 'synthetic-agent',
          expiresAt: '2099-01-01T00:00:00Z',
        }),
      })
      const value = await sessionStorage.save(session)
      const cookie = await sessionCookie.serialize(JSON.stringify({ value, expires: Date.now() + 60000 }))
      for (const scenario of ['preflight', 'connection-lost', 'completed']) {
        let writes = 0
        globalThis.fetch = async (input, options) => {
          const url = new URL(String(input))
          if (url.pathname === '/demo/permissions' && scenario !== 'preflight')
            return Response.json({ permissions: [] })
          if (url.pathname === '/v1/people' && options?.method === 'POST') {
            writes++
            if (scenario === 'completed')
              return Response.json({ id: 'created-sample', display_name: 'Sample person' }, { status: 201 })
          }
          throw new Error('Synthetic upstream connection lost')
        }
        const response = await router.fetch(
          new Request('http://localhost/lab/execute', {
            method: 'POST',
            headers: { Cookie: cookie.split(';')[0], 'Content-Type': 'application/json' },
            body: JSON.stringify({
              name: 'createPerson',
              args: { body: { person: { display_name: 'Sample person' } } },
            }),
          }),
        )
        const result = await response.json()
        assert.equal(writes, scenario === 'preflight' ? 0 : 1)
        if (scenario === 'completed') {
          assert.equal(result.ok, true)
          assert.equal(result.status, 201)
          assert.equal(result.output.id, 'created-sample')
          assert.match(result.warning, /supporting context could not refresh/)
        } else {
          assert.equal(result.ok, false)
          assert.equal(result.outcome, scenario === 'connection-lost' ? 'unknown' : undefined)
        }
      }
    } finally {
      globalThis.fetch = originalFetch
      if (previousDirectory === undefined) delete process.env.LAB_CREDENTIAL_DIR
      else process.env.LAB_CREDENTIAL_DIR = previousDirectory
      rmSync(directory, { recursive: true, force: true })
    }
  })
})

describe('lab persona continuity', () => {
  it('carries the authenticated persona across technical interfaces and rejects expired or unavailable personas', async () => {
    const previousDirectory = process.env.LAB_CREDENTIAL_DIR
    const directory = mkdtempSync(join(tmpdir(), 'lab-persona-test-'))
    process.env.LAB_CREDENTIAL_DIR = directory
    const originalFetch = globalThis.fetch
    try {
      const session = await sessionStorage.read(null)
      session.set('token', 'sample-browser')
      session.set('demo', '1')
      session.set('userId', 'selected-user')
      session.set('email', 'recruiter@bigbuck.test')
      session.set('name', 'Riley Recruiter')
      session.set('roleKey', 'recruiter')
      session.set('lab', {
        surface: 'api',
        sandbox: 'api',
        generation: 1,
        mode: 'compare',
        runKey: 'sample',
        resetsAt: '2099-01-01T00:00:00Z',
        credentialKey: storeLabCredentials({
          toolToken: 'sample-tool',
          agentToken: 'sample-agent',
          expiresAt: '2099-01-01T00:00:00Z',
        }),
      })
      const value = await sessionStorage.save(session)
      let cookie = (
        await sessionCookie.serialize(JSON.stringify({ value, expires: Date.now() + 60000 }))
      ).split(';')[0]
      let sourceValid = true
      let role = 'recruiter'
      const starts: Array<{ surface: string; email: string; generation: number }> = []
      globalThis.fetch = async (input, options) => {
        const url = new URL(String(input))
        if (url.pathname === '/v1/sessions/current')
          return Response.json({}, { status: sourceValid ? 200 : 401 })
        if (url.pathname.startsWith('/demo/sandboxes/'))
          return Response.json({
            sandbox: {
              surface: url.pathname.split('/').pop(),
              generation: 3,
              resets_at: '2099-01-01T00:00:00Z',
            },
            roles: [
              {
                email: 'recruiter@bigbuck.test',
                name: 'Riley Recruiter',
                role_key: role,
                role_name: role,
                permissions: [],
              },
            ],
          })
        if (url.pathname === '/demo/sessions') {
          const body = JSON.parse(String(options?.body))
          starts.push(body)
          return Response.json({
            sandbox: { generation: 3, resets_at: '2099-01-01T00:00:00Z' },
            organization: { id: `${body.surface}-org`, slug: `demo-${body.surface}` },
            user: { id: 'selected-user', email: body.email, name: 'Riley Recruiter' },
            role_key: 'recruiter',
            permissions: ['people:read'],
            session: { token: 'sample-browser' },
            tools: { token: 'sample-tool', agent_token: 'sample-agent' },
          })
        }
        throw new Error(`Unexpected request: ${url.pathname}`)
      }
      const switchTo = (surface: string) =>
        router.fetch(
          new Request('http://localhost/lab', {
            method: 'POST',
            headers: { Cookie: cookie, 'Content-Type': 'application/x-www-form-urlencoded' },
            // Posted identity/generation cannot override the authenticated persona or target generation.
            body: new URLSearchParams({
              intent: 'switch-interface',
              surface,
              mode: 'compare',
              email: 'owner@bigbuck.test',
              generation: '999',
            }),
          }),
        )
      for (const surface of ['mcp', 'cli', 'api']) {
        const response = await switchTo(surface)
        assert.equal(response.status, 303)
        cookie = response.headers.get('Set-Cookie')!.split(';')[0]
        const parsed = await sessionCookie.parse(cookie)
        if (!parsed) throw new Error('Expected a signed session cookie')
        const saved = await sessionStorage.read(JSON.parse(parsed).value)
        assert.equal(saved.get('email'), 'recruiter@bigbuck.test')
        assert.equal(saved.get('roleKey'), 'recruiter')
        assert.equal((saved.get('lab') as any).surface, surface)
        assert.equal((saved.get('lab') as any).mode, 'compare')
        assert.equal((saved.get('lab') as any).generation, 3)
      }
      assert.deepEqual(
        starts,
        ['mcp', 'cli', 'api'].map((surface) => ({ surface, email: 'recruiter@bigbuck.test', generation: 3 })),
      )
      // Selecting the active interface does not create another session.
      assert.equal((await switchTo('api')).status, 303)
      assert.equal(starts.length, 3)
      sourceValid = false
      assert.match(await (await switchTo('mcp')).text(), /expired/)
      assert.equal(starts.length, 3)
      sourceValid = true
      role = 'owner'
      assert.match(await (await switchTo('mcp')).text(), /selected persona is unavailable/)
      assert.equal(starts.length, 3)
    } finally {
      globalThis.fetch = originalFetch
      if (previousDirectory === undefined) delete process.env.LAB_CREDENTIAL_DIR
      else process.env.LAB_CREDENTIAL_DIR = previousDirectory
      rmSync(directory, { recursive: true, force: true })
    }
  })
})

describe('lab reset generation', () => {
  it('drops handoff evidence on reset and never applies old record IDs after re-entry', async () => {
    const previousDirectory = process.env.LAB_CREDENTIAL_DIR
    const directory = mkdtempSync(join(tmpdir(), 'lab-reset-test-'))
    process.env.LAB_CREDENTIAL_DIR = directory
    const originalFetch = globalThis.fetch
    try {
      const session = await sessionStorage.read(null)
      session.set('token', 'sample-browser')
      session.set('userId', 'sample-persona')
      session.set('lab', {
        surface: 'api',
        sandbox: 'api',
        generation: 1,
        mode: 'connect',
        runKey: 'sample',
        evidence: {
          person: 'expired-person-id',
          pool: 'expired-pool-id',
          plan: 'expired-plan-id',
          'ui:open': 'observed',
        },
        resetsAt: '2099-01-01T00:00:00Z',
        credentialKey: storeLabCredentials({
          toolToken: 'sample-tool',
          agentToken: 'sample-agent',
          expiresAt: '2099-01-01T00:00:00Z',
        }),
      })
      const value = await sessionStorage.save(session)
      const cookie = (
        await sessionCookie.serialize(JSON.stringify({ value, expires: Date.now() + 60000 }))
      ).split(';')[0]
      globalThis.fetch = async (input, options) => {
        const url = new URL(String(input))
        if (url.pathname === '/demo/sandboxes/api')
          return Response.json({ sandbox: { generation: 2 }, roles: [] })
        if (url.pathname === '/demo/sessions')
          return Response.json({
            sandbox: { generation: 2, resets_at: '2099-01-01T00:00:00Z' },
            organization: { id: 'new-org', slug: 'demo-api' },
            user: { id: 'sample-persona', name: 'Sample persona', email: 'sample@bigbuck.test' },
            role_key: 'recruiter',
            permissions: [],
            session: { token: 'sample-browser' },
            tools: { token: 'sample-tool', agent_token: 'sample-agent' },
          })
        if (options?.method === 'POST') throw new Error('Unexpected write after reset')
        assert.equal(url.pathname.includes('expired-'), false)
        return Response.json({ data: [] })
      }
      const reset = await router.fetch(
        new Request('http://localhost/lab/status', { headers: { Cookie: cookie } }),
      )
      assert.equal(reset.status, 409)
      const resetCookie = reset.headers.get('Set-Cookie')!.split(';')[0]
      const readCookie = async (header: string) => {
        const parsed = await sessionCookie.parse(header)
        if (!parsed) throw new Error('Expected a signed session cookie')
        return sessionStorage.read(JSON.parse(parsed).value)
      }
      const invalidated = await readCookie(resetCookie)
      assert.equal((invalidated.get('lab') as any).evidence, undefined)
      assert.equal((invalidated.get('lab') as any).generation, 1)
      const restart = await router.fetch(
        new Request('http://localhost/lab', {
          method: 'POST',
          headers: { Cookie: resetCookie, 'Content-Type': 'application/x-www-form-urlencoded' },
          body: 'surface=api&mode=explore&email=sample%40bigbuck.test&generation=2',
        }),
      )
      assert.equal(restart.status, 303)
      const newCookie = restart.headers.get('Set-Cookie')!.split(';')[0]
      const renewed = await readCookie(newCookie)
      assert.equal((renewed.get('lab') as any).generation, 2)
      assert.equal((renewed.get('lab') as any).evidence, undefined)
      const page = await router.fetch(new Request('http://localhost/lab', { headers: { Cookie: newCookie } }))
      const html = await page.text()
      assert.equal(page.status, 200)
      for (const id of ['expired-person-id', 'expired-pool-id', 'expired-plan-id'])
        assert.equal(html.includes(id), false)
    } finally {
      globalThis.fetch = originalFetch
      if (previousDirectory === undefined) delete process.env.LAB_CREDENTIAL_DIR
      else process.env.LAB_CREDENTIAL_DIR = previousDirectory
      rmSync(directory, { recursive: true, force: true })
    }
  })
})

describe('direct UI lab handoff', () => {
  it('opens Today or the selected recruiting step without rendering a UI workbench', async () => {
    const previousDirectory = process.env.LAB_CREDENTIAL_DIR
    const directory = mkdtempSync(join(tmpdir(), 'lab-ui-handoff-test-'))
    process.env.LAB_CREDENTIAL_DIR = directory
    const originalFetch = globalThis.fetch
    try {
      const cookieFor = async (sandbox: string, resetsAt = '2099-01-01T00:00:00Z') => {
        const session = await sessionStorage.read(null)
        session.set('token', 'sample-browser')
        session.set('lab', {
          surface: sandbox,
          sandbox,
          generation: 1,
          mode: 'explore',
          runKey: 'sample',
          resetsAt,
          credentialKey: storeLabCredentials({
            toolToken: 'sample-tool',
            agentToken: 'sample-agent',
            expiresAt: '2099-01-01T00:00:00Z',
          }),
        })
        const value = await sessionStorage.save(session)
        return (await sessionCookie.serialize(JSON.stringify({ value, expires: Date.now() + 60000 }))).split(
          ';',
        )[0]
      }
      globalThis.fetch = async (input) => {
        const url = new URL(String(input))
        if (url.pathname === '/v1/sessions/current') return Response.json({})
        if (url.pathname === '/v1/people' && url.searchParams.get('q')?.startsWith('Nova Lab'))
          return Response.json({
            data: [{ id: 'current-generation-person', display_name: 'Nova Lab sample' }],
          })
        return Response.json({ data: [] })
      }
      const cookie = await cookieFor('ui')
      for (const mode of ['explore', 'compare']) {
        const response = await router.fetch(
          new Request(`http://localhost/lab?surface=ui&mode=${mode}`, { headers: { Cookie: cookie } }),
        )
        assert.equal(response.status, 303)
        assert.equal(response.headers.get('Location'), '/today')
      }
      const connected = await router.fetch(
        new Request('http://localhost/lab?surface=ui&mode=connect&step=open', {
          headers: { Cookie: await cookieFor('cli') },
        }),
      )
      assert.equal(connected.status, 303)
      assert.equal(connected.headers.get('Location'), '/people/current-generation-person?labStep=open')
      const expired = await router.fetch(
        new Request('http://localhost/lab?surface=ui&mode=explore', {
          headers: { Cookie: await cookieFor('ui', '2000-01-01T00:00:00Z') },
        }),
      )
      assert.equal(expired.status, 303)
      assert.equal(expired.headers.get('Location'), '/session?surface=ui&mode=explore')
      const anonymous = await router.fetch(new URL('http://localhost/lab?surface=ui&mode=explore'))
      assert.equal(anonymous.headers.get('Location'), '/session?surface=ui&mode=explore')
    } finally {
      globalThis.fetch = originalFetch
      if (previousDirectory === undefined) delete process.env.LAB_CREDENTIAL_DIR
      else process.env.LAB_CREDENTIAL_DIR = previousDirectory
      rmSync(directory, { recursive: true, force: true })
    }
  })
})

describe('lab temporary availability', () => {
  it('keeps the selected persona on throttling or service failure and offers a safe workspace retry', async () => {
    const previousDirectory = process.env.LAB_CREDENTIAL_DIR
    const directory = mkdtempSync(join(tmpdir(), 'lab-availability-test-'))
    process.env.LAB_CREDENTIAL_DIR = directory
    const originalFetch = globalThis.fetch
    try {
      const session = await sessionStorage.read(null)
      session.set('token', 'sample-browser')
      session.set('demo', '1')
      session.set('userId', 'sample-persona')
      session.set('email', 'hm@bigbuck.test')
      session.set('name', 'Harper Manager')
      session.set('roleKey', 'hiring_manager')
      session.set('lab', {
        surface: 'api',
        sandbox: 'api',
        generation: 1,
        mode: 'compare',
        runKey: 'sample',
        resetsAt: '2099-01-01T00:00:00Z',
        credentialKey: storeLabCredentials({
          toolToken: 'sample-tool',
          agentToken: 'sample-agent',
          expiresAt: '2099-01-01T00:00:00Z',
        }),
      })
      const value = await sessionStorage.save(session)
      const cookie = (
        await sessionCookie.serialize(JSON.stringify({ value, expires: Date.now() + 60000 }))
      ).split(';')[0]
      let status = 429
      let requests = 0
      let starts = 0
      globalThis.fetch = async (input, options) => {
        requests++
        const url = new URL(String(input))
        if (url.pathname === '/demo/sessions') starts++
        if (options?.method === 'POST') throw new Error('Unexpected credential or domain write')
        if (url.pathname === '/v1/sessions/current')
          return Response.json({ title: 'Sample temporary failure' }, { status })
        return Response.json({ data: [] })
      }
      for (const failure of [429, 503]) {
        status = failure
        requests = 0
        const response = await router.fetch(
          new Request('http://localhost/lab?surface=api&mode=compare&operation=listPeople&step=find', {
            headers: { Cookie: cookie },
          }),
        )
        const html = await response.text()
        assert.equal(response.status, failure)
        assert.match(html, /Harper Manager/)
        assert.match(html, /Your persona is still selected/)
        assert.match(html, /Try again/)
        assert.doesNotMatch(html, /Choose a persona|session has expired/)
        assert.match(html, /operation=listPeople/)
        assert.match(html, /step=find/)
        assert.equal(requests, 1, 'The unavailable page fetched more protected workspace data')
      }
      status = 429
      const switched = await router.fetch(
        new Request('http://localhost/lab', {
          method: 'POST',
          headers: { Cookie: cookie, 'Content-Type': 'application/x-www-form-urlencoded' },
          body: 'intent=switch-interface&surface=mcp&mode=compare',
        }),
      )
      assert.equal(switched.status, 429)
      const html = await switched.text()
      assert.match(html, /Harper Manager/)
      assert.match(html, /API lab/)
      assert.doesNotMatch(html, /Choose a persona|session has expired/)
      assert.equal(starts, 0)
      status = 200
      const resumed = await router.fetch(
        new Request('http://localhost/lab?surface=api&mode=compare&operation=listPeople', {
          headers: { Cookie: cookie },
        }),
      )
      assert.equal(resumed.status, 200)
      assert.match(await resumed.text(), /Harper Manager/)
      assert.equal(starts, 0, 'Retry changed the persona instead of reopening the existing workspace')
    } finally {
      globalThis.fetch = originalFetch
      if (previousDirectory === undefined) delete process.env.LAB_CREDENTIAL_DIR
      else process.env.LAB_CREDENTIAL_DIR = previousDirectory
      rmSync(directory, { recursive: true, force: true })
    }
  })
})
