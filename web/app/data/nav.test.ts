import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'

import { activePrimary, isFoldCurrent } from './nav.ts'

describe('folded navigation', () => {
  it('maps child routes onto Big Buck parents', () => {
    assert.equal(activePrimary('/today'), 'today')
    assert.equal(activePrimary('/analytics'), 'today')
    assert.equal(activePrimary('/jobs'), 'jobs')
    assert.equal(activePrimary('/jobs/job_1'), 'jobs')
    assert.equal(activePrimary('/applications/app_1'), 'jobs')
    assert.equal(activePrimary('/requisitions'), 'jobs')
    assert.equal(activePrimary('/people'), 'people')
    assert.equal(activePrimary('/people/person_1'), 'people')
    assert.equal(activePrimary('/pools'), 'people')
    assert.equal(activePrimary('/pools/pool_1'), 'people')
    assert.equal(activePrimary('/pool-members/mem_1'), 'people')
    assert.equal(activePrimary('/referrals'), 'people')
    assert.equal(activePrimary('/companies'), 'people')
    assert.equal(activePrimary('/companies/co_1'), 'people')
    assert.equal(activePrimary('/settings/templates'), 'settings')
    assert.equal(activePrimary('/settings/webhooks'), 'settings')
    assert.equal(activePrimary('/search'), null)
    assert.equal(activePrimary('/interviews'), 'interviews')
    assert.equal(activePrimary('/offers'), 'offers')
    assert.equal(activePrimary('/offers/view/off_1'), 'offers')
    assert.equal(activePrimary('/careers'), 'careers')
    assert.equal(activePrimary('/settings'), 'settings')
    assert.equal(activePrimary('/settings/agents'), 'settings')
    assert.equal(activePrimary('/settings/careers'), 'settings')
    assert.equal(activePrimary('/sequences'), 'settings')
    assert.equal(activePrimary('/admin'), 'settings')
    assert.equal(activePrimary('/'), null)
  })

  it('marks fold links current without stealing the index highlight', () => {
    assert.equal(isFoldCurrent('/people', '/people'), true)
    assert.equal(isFoldCurrent('/people', '/people/new'), false)
    assert.equal(isFoldCurrent('/pools', '/pools/pool_1'), true)
    assert.equal(isFoldCurrent('/settings', '/settings/agents'), false)
    assert.equal(isFoldCurrent('/settings/agents', '/settings/agents'), true)
    assert.equal(isFoldCurrent('/admin#companies', '/admin'), true)
  })

  it('keeps the Archived view and the Applications list as separate highlights', () => {
    assert.equal(isFoldCurrent('/applications?status=archived', '/applications?status=archived'), true)
    assert.equal(isFoldCurrent('/applications', '/applications?status=archived'), false)
    assert.equal(isFoldCurrent('/applications', '/applications?status=hired'), true)
    assert.equal(isFoldCurrent('/applications?status=archived', '/applications'), false)
    assert.equal(isFoldCurrent('/applications?status=archived', '/applications/app_1'), false)
  })
})
