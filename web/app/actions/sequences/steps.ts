// Sequence step editing for the web editor. Rails (`SequenceSteps.normalize`) stays the authority on
// what a valid step is; this only turns the editor's forms into the step list sent to it.

export type Step = Record<string, unknown>

/** Task steps a recruiter does by hand. `task_type` values match `SourcingTask::TYPES`. */
export const taskKinds = [
  { value: 'linkedin', name: 'LinkedIn task', title: 'Send a LinkedIn message' },
  { value: 'call', name: 'Call task', title: 'Call them' },
  { value: 'email', name: 'Personal email task', title: 'Write a personal email' },
  { value: 'other', name: 'Other task', title: 'Follow up' },
] as const

export function taskKind(value: unknown) {
  return taskKinds.find((kind) => kind.value === value) ?? taskKinds[taskKinds.length - 1]!
}

/** One step from an add or edit form. `type` and `id` come from the step being edited, when there is one. */
export function stepFromForm(form: FormData, existing?: Step): Step {
  const text = (name: string) => String(form.get(name) ?? '').trim()
  const days = (name: string, fallback: number) => {
    const value = Math.floor(Number(form.get(name)))
    return Number.isFinite(value) && value > 0 ? value : fallback
  }
  const type = String(existing?.type ?? (text('step_type') || 'email'))
  const id = existing?.id ? { id: existing.id } : {}
  if (type === 'wait') return { ...id, type, days: days('days', 3) }
  if (type === 'task') {
    const kind = taskKind(text('task_type') || existing?.task_type)
    const due = Math.floor(Number(form.get('due_in_days')))
    return {
      ...id,
      type,
      task_type: kind.value,
      title: text('title') || kind.title,
      ...(Number.isFinite(due) && due > 0 ? { due_in_days: due } : {}),
      pause_until_done: form.get('pause_until_done') === 'on',
    }
  }
  const sendAs = text('send_as_user_id')
  return {
    ...id,
    type: 'email',
    template_key: text('template_key'),
    ...(sendAs ? { send_as_user_id: sendAs } : {}),
  }
}

/** Move the step with `id` so it ends up at `toIndex`. Unknown ids and out-of-range indexes change nothing. */
export function moveStep(steps: Step[], id: string, toIndex: number): Step[] {
  const from = steps.findIndex((step) => step.id === id)
  if (from < 0 || !Number.isInteger(toIndex) || toIndex < 0 || toIndex >= steps.length) return steps
  const next = [...steps]
  const [step] = next.splice(from, 1)
  next.splice(toIndex, 0, step!)
  return next
}

/**
 * Apply one editor intent (`step_add`, `step_update:<id>`, `step_remove:<id>`, `step_up:<id>`,
 * `step_down:<id>`, `step_move`) and return the new list.
 */
export function applyStepIntent(steps: Step[], intent: string, form: FormData): Step[] {
  const [action = '', stepId = ''] = intent.split(':')
  const at = steps.findIndex((step) => step.id === stepId)
  if (action === 'step_add') return [...steps, stepFromForm(form)]
  if (action === 'step_move') {
    return moveStep(steps, String(form.get('drag_id') ?? ''), Number(form.get('drag_to')))
  }
  if (at < 0) return steps
  if (action === 'step_remove') return steps.filter((_, index) => index !== at)
  if (action === 'step_up') return moveStep(steps, stepId, at - 1)
  if (action === 'step_down') return moveStep(steps, stepId, at + 1)
  if (action === 'step_update') {
    return steps.map((step, index) => (index === at ? stepFromForm(form, step) : step))
  }
  return steps
}

/** A stable key from a sequence name, so a recruiter never has to invent one. */
export function sequenceKey(name: string, suffix: string): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40)
  return `${slug || 'sequence'}-${suffix}`
}
