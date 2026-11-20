import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import type { Mailbox, Person, Sequence } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { taskKind } from './steps.ts'
import { Field, Mute, PrimaryButton, RowLink, RowList, Shell } from '../../ui/shell.tsx'

export function SequencesIndexPage(
  handle: Handle<{
    sequences: Sequence[]
    people: Person[]
    mailboxes: Mailbox[]
    orgQuery: string
    notice?: string
  }>,
) {
  return () => {
    let { sequences, people, mailboxes, orgQuery, notice } = handle.props
    return (
      <Shell title="Sequences" eyebrow="Outreach" orgQuery={orgQuery}>
        <Mute>Enroll prospects; a reply stops the active enrollment.</Mute>
        {notice ? (
          <p mix={css({ color: 'var(--bb-accent)', fontWeight: 600, marginBottom: '16px' })}>{notice}</p>
        ) : null}

        <details class="workflow-disclosure" open={Boolean(notice)}>
          <summary>Create or enroll</summary>
          <div class="workflow-grid">
            <form
              method="post"
              action={`${routes.sequencesCreate.action.href()}${orgQuery}`}
              mix={css({
                maxWidth: '28rem',
                marginBottom: '28px',
                paddingBottom: '24px',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: 'var(--bb-accent)' })}>
                New sequence
              </h2>
              <input type="hidden" name="intent" value="create" />
              <Field label="Name" name="name" required placeholder="Staff backend outreach" />
              <label
                class="field"
                mix={css({
                  display: 'flex',
                  gap: '8px',
                  alignItems: 'center',
                  marginBottom: '16px',
                  fontSize: '14px',
                })}
              >
                <input type="checkbox" name="is_template" />
                Share as a template teammates can copy
              </label>
              <PrimaryButton type="submit">Create and add steps</PrimaryButton>
            </form>

            <form
              method="post"
              action={`${routes.sequencesCreate.action.href()}${orgQuery}`}
              mix={css({
                maxWidth: '28rem',
                marginBottom: '28px',
                paddingBottom: '24px',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: 'var(--bb-accent)' })}>
                Enroll person
              </h2>
              <input type="hidden" name="intent" value="enroll" />
              <label
                class="field"
                mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' })}
              >
                <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
                  Sequence
                </span>
                <select name="sequence_id" required>
                  {sequences.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </label>
              <label
                class="field"
                mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' })}
              >
                <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
                  Person
                </span>
                <select name="person_id" required>
                  {people.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.display_name}
                    </option>
                  ))}
                </select>
              </label>
              <label
                class="field"
                mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' })}
              >
                <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
                  Mailbox
                </span>
                <select name="mailbox_id">
                  <option value="">Default</option>
                  {mailboxes.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.email} ({label(m.kind)})
                    </option>
                  ))}
                </select>
              </label>
              <PrimaryButton type="submit">Enroll & send</PrimaryButton>
            </form>
          </div>
        </details>
        <p class="sub mute">{sequences.length} sequences shown</p>
        <RowList>
          {sequences.map((sequence) => (
            <RowLink
              key={sequence.id}
              href={`${routes.sequencesShow.index.href({ sequenceId: sequence.id })}${orgQuery}`}
              title={sequence.name}
              meta={`${stepSummary(sequence)} · ${sequence.enrollment_count ?? 0} enrolled · ${label(sequence.status)}${sequence.is_template ? ' · Template' : ''}`}
            />
          ))}
        </RowList>
      </Shell>
    )
  }
}

export function stepSummary(sequence: Sequence): string {
  const steps = sequence.steps ?? []
  const emails = steps.filter((step) => step.type === 'email').length
  return `${steps.length} ${steps.length === 1 ? 'step' : 'steps'}${emails ? ` · ${emails} ${emails === 1 ? 'email' : 'emails'}` : ''}`
}

export function stepLabel(
  step: Record<string, unknown>,
  templates: Map<string, string>,
  senders: Map<string, string> = new Map(),
): { title: string; detail: string } {
  const type = String(step.type ?? '')
  if (type === 'email') {
    const key = String(step.template_key ?? '')
    const sender = step.send_as_user_id ? senders.get(String(step.send_as_user_id)) : undefined
    const template = templates.get(key) ?? (key ? label(key) : 'Template not set')
    return {
      title: 'Send email',
      detail: step.send_as_user_id ? `${template} · from ${sender ?? 'a teammate'}` : template,
    }
  }
  if (type === 'wait') {
    const days = Number(step.days ?? 0)
    const hours = Number(step.hours ?? 0)
    const parts = [
      days ? `${days} ${days === 1 ? 'day' : 'days'}` : '',
      hours ? `${hours} ${hours === 1 ? 'hour' : 'hours'}` : '',
    ]
    return { title: 'Wait', detail: parts.filter(Boolean).join(' ') || 'No delay' }
  }
  if (type === 'task') {
    const due = Number(step.due_in_days ?? 0)
    const parts = [
      String(step.title ?? 'Follow up'),
      due ? `due in ${due} ${due === 1 ? 'day' : 'days'}` : '',
      // Rails treats a task without the flag as one that holds the sequence.
      step.pause_until_done === false ? '' : 'sequence waits until it is done',
    ]
    return { title: taskKind(step.task_type).name, detail: parts.filter(Boolean).join(' · ') }
  }
  return { title: label(type), detail: '' }
}
