import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'

import {
  columnsForSection,
  defaultSection,
  jobWorkspaceHref,
  previewMove,
  sectionForStage,
  skippedInterviewStages,
  stageAgeLabel,
  stageEnteredAt,
} from './board.ts'

const stages = [
  { key: 'sourced', name: 'Sourced', type: 'lead' },
  { key: 'applied', name: 'Applied', type: 'apply' },
  { key: 'screen', name: 'Screen', type: 'screen' },
  { key: 'onsite', name: 'Onsite', type: 'interview' },
  { key: 'offer', name: 'Offer', type: 'offer' },
]

describe('pipeline sections', () => {
  it('maps stage types onto Lead, Review, Active, and Offer', () => {
    assert.equal(sectionForStage({ key: 'sourced', type: 'lead' }), 'lead')
    assert.equal(sectionForStage({ key: 'applied', type: 'apply' }), 'review')
    assert.equal(sectionForStage({ key: 'onsite', type: 'interview' }), 'active')
    assert.equal(sectionForStage({ key: 'offer', type: 'offer' }), 'offer')
    assert.equal(sectionForStage({ key: 'recruiter-screen' }), 'active')
  })

  it('opens the full pipeline and keeps section filters available', () => {
    const apps = [
      { id: 'a', status: 'active', stageKey: 'onsite', name: 'Ava' },
      { id: 'b', status: 'rejected', stageKey: 'applied', name: 'Tess' },
    ]
    assert.equal(defaultSection(stages, apps), 'all')
    assert.deepEqual(columnsForSection('all', stages, apps), stages)
    assert.deepEqual(
      columnsForSection('active', stages, apps).map((stage) => stage.key),
      ['screen', 'onsite'],
    )
    assert.deepEqual(
      columnsForSection('closed', stages, apps).map((stage) => stage.key),
      ['applied'],
    )
  })
})

describe('stage aging', () => {
  const now = Date.parse('2026-11-04T12:00:00.000Z')

  it('uses the latest move into the current stage', () => {
    assert.equal(
      stageEnteredAt({
        currentStageKey: 'onsite',
        updatedAt: '2026-11-01T12:00:00.000Z',
        transitions: [
          { toStageKey: 'applied', createdAt: '2026-10-01T12:00:00.000Z' },
          { toStageKey: 'onsite', createdAt: '2026-11-02T12:00:00.000Z' },
        ],
      }),
      '2026-11-02T12:00:00.000Z',
    )
  })

  it('labels days, hours, and minutes', () => {
    assert.equal(stageAgeLabel('2026-10-30T12:00:00.000Z', now), '5d')
    assert.equal(stageAgeLabel('2026-11-04T09:00:00.000Z', now), '3h')
    assert.equal(stageAgeLabel('2026-11-04T11:40:00.000Z', now), '20m')
    assert.equal(stageAgeLabel('2026-11-04T11:59:30.000Z', now), 'just now')
  })
})

describe('skipped interview stages', () => {
  const planned = [
    { key: 'applied', name: 'Applied' },
    { key: 'screen', name: 'Screen', interviews: [{ required: false }] },
    { key: 'onsite', name: 'Onsite', interviews: [{}, { required: true }] },
    { key: 'offer', name: 'Offer' },
  ]

  it('names stages with required interviews that a forward move jumps over', () => {
    assert.deepEqual(skippedInterviewStages(planned, 'applied', 'offer'), ['Onsite'])
    assert.deepEqual(skippedInterviewStages(planned, 'onsite', 'offer'), [])
    assert.deepEqual(skippedInterviewStages(planned, 'offer', 'applied'), [])
    assert.deepEqual(skippedInterviewStages(planned, 'missing', 'offer'), [])
  })
})

describe('move preview', () => {
  const apps = [{ id: 'app-ava', status: 'active', stageKey: 'applied', name: 'Ava Chen' }]

  it('stays quiet until a candidate and a stage are both chosen', () => {
    assert.equal(previewMove({ applicationId: '', toStageKey: '', applications: apps, stages }), null)
    const partial = previewMove({ applicationId: 'app-ava', toStageKey: '', applications: apps, stages })
    assert.equal(partial?.ok, false)
  })

  it('describes the move and refuses a same-stage drop', () => {
    const preview = previewMove({
      applicationId: 'app-ava',
      toStageKey: 'onsite',
      applications: apps,
      stages,
    })
    assert.equal(preview?.ok, true)
    if (preview?.ok) {
      assert.equal(preview.fromLabel, 'Applied')
      assert.equal(preview.toLabel, 'Onsite')
    }
    const same = previewMove({
      applicationId: 'app-ava',
      toStageKey: 'applied',
      applications: apps,
      stages,
    })
    assert.equal(same?.ok, false)
  })
})

describe('job workspace links', () => {
  it('keeps the careers slug and adds the tab', () => {
    assert.equal(
      jobWorkspaceHref('job_1', '?slug=big-buck', { tab: 'settings' }),
      '/jobs/job_1?slug=big-buck&tab=settings',
    )
    assert.equal(jobWorkspaceHref('job_1', '', { tab: 'pipeline' }), '/jobs/job_1?tab=pipeline')
  })
})
