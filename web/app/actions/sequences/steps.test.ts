import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'

import { applyStepIntent, moveStep, sequenceKey, stepFromForm } from './steps.ts'

function form(values: Record<string, string>) {
  const data = new FormData()
  for (const [name, value] of Object.entries(values)) data.set(name, value)
  return data
}

const steps = [
  { id: 'a', type: 'email', template_key: 'intro' },
  { id: 'b', type: 'wait', days: 3 },
  { id: 'c', type: 'task', task_type: 'linkedin', title: 'Connect', pause_until_done: true },
]

describe('sequence step editing', () => {
  it('builds each kind of step from the add form', () => {
    assert.deepEqual(stepFromForm(form({ step_type: 'email', template_key: 'intro' })), {
      type: 'email',
      template_key: 'intro',
    })
    assert.deepEqual(
      stepFromForm(form({ step_type: 'email', template_key: 'intro', send_as_user_id: 'u-1' })),
      { type: 'email', template_key: 'intro', send_as_user_id: 'u-1' },
    )
    assert.deepEqual(stepFromForm(form({ step_type: 'wait', days: '5' })), { type: 'wait', days: 5 })
    assert.deepEqual(stepFromForm(form({ step_type: 'wait', days: '-2' })), { type: 'wait', days: 3 })
    assert.deepEqual(
      stepFromForm(form({ step_type: 'task', task_type: 'linkedin', pause_until_done: 'on' })),
      { type: 'task', task_type: 'linkedin', title: 'Send a LinkedIn message', pause_until_done: true },
    )
    // An unchecked box is absent from the form: the task must not pause the sequence.
    assert.deepEqual(
      stepFromForm(form({ step_type: 'task', task_type: 'call', title: 'Ring Sam', due_in_days: '2' })),
      { type: 'task', task_type: 'call', title: 'Ring Sam', due_in_days: 2, pause_until_done: false },
    )
  })

  it('keeps the id and type when a step is edited', () => {
    const next = applyStepIntent(steps, 'step_update:b', form({ step_type: 'email', days: '7' }))
    assert.deepEqual(next[1], { id: 'b', type: 'wait', days: 7 })
    assert.equal(next.length, 3)
    const task = applyStepIntent(steps, 'step_update:c', form({ title: 'Message them' }))
    assert.deepEqual(task[2], {
      id: 'c',
      type: 'task',
      task_type: 'linkedin',
      title: 'Message them',
      pause_until_done: false,
    })
  })

  it('adds, removes and reorders', () => {
    const ids = (list: typeof steps) => list.map((step) => step.id)
    assert.equal(applyStepIntent(steps, 'step_add', form({ step_type: 'wait', days: '1' })).length, 4)
    assert.deepEqual(ids(applyStepIntent(steps, 'step_remove:b', form({})) as typeof steps), ['a', 'c'])
    assert.deepEqual(ids(applyStepIntent(steps, 'step_up:c', form({})) as typeof steps), ['a', 'c', 'b'])
    assert.deepEqual(ids(applyStepIntent(steps, 'step_down:a', form({})) as typeof steps), ['b', 'a', 'c'])
    assert.deepEqual(
      ids(applyStepIntent(steps, 'step_move', form({ drag_id: 'c', drag_to: '0' })) as typeof steps),
      ['c', 'a', 'b'],
    )
  })

  it('ignores moves that point nowhere', () => {
    assert.equal(moveStep(steps, 'missing', 0), steps)
    assert.equal(moveStep(steps, 'a', 9), steps)
    assert.equal(moveStep(steps, 'a', -1), steps)
    assert.equal(applyStepIntent(steps, 'step_up:a', form({})), steps)
    assert.equal(applyStepIntent(steps, 'step_remove:missing', form({})), steps)
    assert.equal(applyStepIntent(steps, 'step_move', form({ drag_id: 'a', drag_to: 'x' })), steps)
  })

  it('derives a key from the name', () => {
    assert.equal(sequenceKey('Staff Backend — Philly!', 'k3f9'), 'staff-backend-philly-k3f9')
    assert.equal(sequenceKey('   ', 'k3f9'), 'sequence-k3f9')
  })
})
