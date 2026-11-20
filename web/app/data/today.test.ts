import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'
import { loadToday } from './today.ts'

const core = {
  viewer: { user: { id: 'me', name: 'Sample person' } },
  today: { reviews: [], feedback: [], upcoming: [] },
}

describe('Today section loading', () => {
  it('keeps successful queues when another read fails, and distinguishes empty from omitted', async () => {
    const original = globalThis.fetch
    const calls: string[] = []
    let failure: 'offers' | 'core' | 'partial' | 'permission' | null = 'offers'
    globalThis.fetch = async (_input, options) => {
      const name = JSON.parse(String(options?.body)).operationName
      calls.push(name)
      if (failure === 'offers' && name === 'TodayOffers') return new Response(null, { status: 503 })
      if (failure === 'core' && name === 'Today') return new Response(null, { status: 502 })
      if (failure === 'partial' && name === 'TodayJobs')
        return Response.json({ data: { today: null }, errors: [{ message: 'Sample error' }] })
      if (failure === 'permission' && name === 'TodayOffers')
        return Response.json({
          errors: [{ message: 'Hidden', extensions: { code: 'insufficient_permission' } }],
        })
      return Response.json({
        data:
          name === 'Today' ? core : { today: name === 'TodayOffers' ? { offersPending: [] } : { jobs: [] } },
      })
    }
    try {
      const session = { token: 'fixture-only' }
      const permissions = ['application.read', 'offer.read', 'job.read', 'scorecard.write']
      let data = await loadToday(session, permissions)
      assert.equal(data.core.status, 'ready')
      assert.equal(data.offers.status, 'failed')
      assert.deepEqual(data.jobs, { status: 'ready', data: [] })
      failure = 'core'
      data = await loadToday(session, permissions)
      assert.equal(data.core.status, 'failed')
      assert.equal(data.offers.status, 'ready')
      assert.equal(data.jobs.status, 'ready')
      failure = 'partial'
      assert.equal((await loadToday(session, permissions)).jobs.status, 'failed')
      failure = 'permission'
      assert.equal((await loadToday(session, permissions)).offers.status, 'omitted')
      failure = null
      assert.equal((await loadToday(session, permissions)).offers.status, 'ready')
      calls.length = 0
      data = await loadToday(session, ['application.read', 'scorecard.write'])
      assert.deepEqual(calls, ['Today'])
      assert.equal(data.offers.status, 'omitted')
      assert.equal(data.jobs.status, 'omitted')
      assert.equal(data.canWriteFeedback, true)
      assert.equal(data.canViewAnalytics, false)
      assert.equal(data.canManageAgents, false)
      calls.length = 0
      data = await loadToday(session, [])
      assert.deepEqual(calls, [])
      assert.equal(data.core.status, 'omitted')
      assert.equal(data.offers.status, 'omitted')
      assert.equal(data.jobs.status, 'omitted')
    } finally {
      globalThis.fetch = original
    }
  })
})
