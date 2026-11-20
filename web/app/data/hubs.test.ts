import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'

import {
  buildTodayView,
  needsYouLine,
  offerCounts,
  selectInterviewTab,
  selectOfferTab,
  type HubInterview,
} from './hubs.ts'

const interview = (id: string, interviewers: string[]): HubInterview => ({
  id,
  applicationId: 'app',
  interviewKey: 'hm',
  status: 'scheduled',
  startsAt: '2026-11-05T16:00:00.000Z',
  interviewerUserIds: interviewers,
  application: { id: 'app', person: { displayName: id }, job: { title: 'Platform' } },
})

describe('hub view models', () => {
  it('counts things that need you and keeps offers off the queue without permission', () => {
    assert.equal(needsYouLine(0), 'Nothing needs you')
    assert.equal(needsYouLine(1), '1 thing needs you')
    assert.equal(needsYouLine(3), '3 things need you')

    const hidden = buildTodayView({
      userId: 'user',
      reviews: [
        { id: 'app-1', person: { displayName: 'Ava Chen' }, job: { id: 'job', title: 'Platform Engineer' } },
      ],
      feedback: [],
      upcoming: [],
      offersPending: null,
      jobs: null,
      kind: 'offers',
    })
    assert.equal(hidden.offersPending, null)
    assert.equal(
      hidden.pills.some((pill) => pill.kind === 'offers'),
      false,
    )
    assert.equal(hidden.items.length, 1)
    assert.equal(hidden.items[0]?.cta, 'Review')
    assert.match(hidden.items[0]?.why ?? '', /Platform Engineer/)
  })

  it('keeps Today personal, separates future days, and preserves scoped destinations', () => {
    const now = Date.parse('2026-11-05T14:00:00Z')
    const row = (id: string, at: string, ids = ['me']) => ({ ...interview(id, ids), startsAt: at })
    const input = {
      userId: 'me',
      now,
      timeZone: 'America/New_York',
      kind: null,
      orgQuery: '?org=demo',
      reviews: [],
      offersPending: null,
      jobs: null,
      feedback: [row('feedback', '2026-11-04T16:00:00Z')],
      upcoming: [
        row('today', '2026-11-05T16:00:00Z'),
        row('other', '2026-11-05T16:00:00Z', ['other']),
        row('tomorrow', '2026-11-06T16:00:00Z'),
        row('late-today', '2026-11-06T02:00:00Z'),
      ],
    }
    const view = buildTodayView(input)
    assert.deepEqual(
      view.interviewsToday.map((item) => item.id),
      ['today', 'late-today'],
    )
    assert.deepEqual(
      view.thisWeek.map((item) => item.id),
      ['tomorrow'],
    )
    assert.equal(view.feedbackPending[0]?.title, 'feedback')
    assert.equal(view.interviewsHref, '/interviews?org=demo&tab=upcoming')
    assert.equal(view.applicationsHref, '/today?org=demo&kind=reviews#applications')
    assert.equal(buildTodayView({ ...input, userId: null }).interviewsToday.length, 0)
    assert.deepEqual(
      buildTodayView({ ...input, timeZone: 'UTC' }).interviewsToday.map((item) => item.id),
      ['today'],
    )
  })

  it('omits past and invalid starts from the remaining-day schedule', () => {
    const view = buildTodayView({
      userId: 'me',
      now: Date.parse('2026-11-05T14:00:00Z'),
      timeZone: 'UTC',
      reviews: [],
      feedback: [],
      offersPending: [],
      jobs: [],
      kind: null,
      upcoming: [
        { ...interview('past', ['me']), startsAt: '2026-11-05T13:00:00Z' },
        { ...interview('invalid', ['me']), startsAt: 'bad' },
        { ...interview('missing', ['me']), startsAt: null },
      ],
    })
    assert.equal(view.interviewsToday.length, 0)
    assert.equal(view.thisWeek.length, 0)
  })

  it('opens interviews on the first non-empty tab', () => {
    assert.equal(selectInterviewTab(null, { upcoming: 0, schedule: 2, feedback: 0, mine: 1 }), 'schedule')
    assert.equal(
      selectInterviewTab('feedback', { upcoming: 3, schedule: 2, feedback: 0, mine: 1 }),
      'feedback',
    )
    assert.equal(selectInterviewTab('nope', { upcoming: 0, schedule: 0, feedback: 0, mine: 0 }), 'upcoming')
  })

  it('opens offers on the first status with a count and keeps the Approve tab', () => {
    const counts = offerCounts([
      { status: 'draft', count: 0 },
      { status: 'pending_approval', count: 1 },
    ])
    assert.equal(counts.draft, 0)
    assert.equal(counts.pending_approval, 1)
    assert.equal(counts.sent, 0)
    assert.equal(selectOfferTab(null, counts), 'pending')
    assert.equal(selectOfferTab('drafts', counts), 'drafts')
    assert.equal(selectOfferTab('approve', counts), 'pending')
    assert.equal(selectOfferTab('pending_approval', counts), 'pending')
    assert.equal(selectOfferTab('Changes requested', counts), 'changes')
  })
})
