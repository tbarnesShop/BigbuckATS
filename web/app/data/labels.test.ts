import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { label, statusTone, whenLabel } from './labels.ts'

describe('labels', () => {
  it('never shows stored snake_case values', () => {
    assert.equal(label('pending_approval'), 'Waiting for approval')
    assert.equal(label('hiring-manager'), 'Hiring manager')
    assert.equal(label('full_time'), 'Full-time')
    assert.equal(label('some_new_status'), 'Some new status')
    assert.equal(label(null), '—')
  })

  it('tones statuses by outcome', () => {
    assert.equal(statusTone('hired'), 'chip chip-ok')
    assert.equal(statusTone('pending_approval'), 'chip chip-warn')
    assert.equal(statusTone('rejected'), 'chip chip-bad')
  })

  it('states the time zone on interview times', () => {
    assert.match(whenLabel('2026-11-10T20:30:00Z'), /^Tue, Nov 10 · 3:30 PM EST$/)
    assert.equal(whenLabel('not a date'), '')
  })
})
