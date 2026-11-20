import type { Handle } from 'remix/component'

import { REPLY_LABELS } from '../../data/api.ts'
import type { FeedItem, Mailbox, MessageTemplate, Person, PersonTagRow } from '../../data/api.ts'
import { label, whenLabel } from '../../data/labels.ts'
import { RecordActionMenu } from '../../ui/record-action-menu.tsx'
import { EmptyState, Field, PrimaryButton } from '../../ui/shell.tsx'

export type PersonCrm = {
  feed: FeedItem[]
  tags: PersonTagRow[]
  allTags: PersonTagRow[]
  templates: MessageTemplate[]
  mailboxes: Mailbox[]
}

export type MessagePreview = { subject: string; body: string }

type Props = {
  person: Person
  crm: PersonCrm
  action: string
  permissions: string[]
  orgQuery?: string
  preview?: MessagePreview
  draft?: Record<string, string>
}

/** The relationship record: who they are to us, tags, composers, and one feed of everything that happened. */
export function PersonActivity(handle: Handle<Props>) {
  return () => {
    let { person, crm, action, permissions, preview, draft = {} } = handle.props
    let canEdit = permissions.includes('person.update')
    let canSend = permissions.includes('communication.send')
    let sendable = crm.mailboxes.filter((mailbox) => mailbox.status === 'connected')
    let threadSizes = new Map<string, number>()
    for (let item of crm.feed)
      if (item.kind === 'email' && item.thread_id)
        threadSizes.set(item.thread_id, (threadSizes.get(item.thread_id) ?? 0) + 1)
    return (
      <div class="stack">
        {canSend || canEdit ? (
          <div class="person-actions" role="group" aria-label="Actions">
            {canSend ? (
              <RecordActionMenu
                label="Email"
                wide
                initiallyOpen={Boolean(preview || draft.body || draft.subject)}
              >
                <h2>Email {person.display_name}</h2>
                {person.do_not_contact ? (
                  <p class="mute">This person is marked do not contact. Sending is blocked.</p>
                ) : sendable.length === 0 ? (
                  <p class="mute">Connect a mailbox in Settings to send email from here.</p>
                ) : (
                  <form method="post" action={action} class="form-narrow">
                    <label class="field">
                      <span>From</span>
                      <select name="mailbox_id">
                        {sendable.map((mailbox) => (
                          <option
                            key={mailbox.id}
                            value={mailbox.id}
                            selected={draft.mailbox_id === mailbox.id}
                          >
                            {mailbox.email}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label class="field">
                      <span>Template</span>
                      <select name="template_key">
                        <option value="">Write my own</option>
                        {crm.templates.map((template) => (
                          <option
                            key={template.id}
                            value={template.key}
                            selected={draft.template_key === template.key}
                          >
                            {template.name || template.key}
                          </option>
                        ))}
                      </select>
                    </label>
                    <input type="hidden" name="thread_id" value={draft.thread_id ?? ''} />
                    <input type="hidden" name="in_reply_to" value={draft.in_reply_to ?? ''} />
                    <Field
                      label="Subject (blank uses the template)"
                      name="subject"
                      defaultValue={draft.subject}
                    />
                    <label class="field">
                      <span>Body (blank uses the template)</span>
                      <textarea name="body" rows={6} defaultValue={draft.body ?? ''} />
                    </label>
                    <p class="hint">
                      Merge fields like {'{{person.first_name}}'}, {'{{person.current_company}}'} and{' '}
                      {'{{sender.name}}'} are filled in for this person.
                    </p>
                    <div class="row-actions">
                      <button class="btn btn-ghost" type="submit" name="intent" value="preview_message">
                        Preview
                      </button>
                      <button class="btn btn-primary" type="submit" name="intent" value="message">
                        Send email
                      </button>
                    </div>
                  </form>
                )}
                {preview ? (
                  <div class="message-preview" role="region" aria-label="Preview">
                    <strong>{preview.subject}</strong>
                    <pre>{preview.body}</pre>
                  </div>
                ) : null}
              </RecordActionMenu>
            ) : null}
            {canEdit ? (
              <>
                <RecordActionMenu label="Note">
                  <h2>Note</h2>
                  <form method="post" action={action} class="form-narrow">
                    <input type="hidden" name="intent" value="add_note" />
                    <label class="field">
                      <span>What should the team know?</span>
                      <textarea name="body" rows={4} required />
                    </label>
                    <label class="check">
                      <input type="checkbox" name="pinned" value="1" /> Pin to the top
                    </label>
                    <PrimaryButton type="submit">Add note</PrimaryButton>
                  </form>
                </RecordActionMenu>
                <RecordActionMenu label="Follow-up">
                  <h2>Follow-up</h2>
                  <form method="post" action={action} class="form-narrow">
                    <input type="hidden" name="intent" value="add_task" />
                    <Field label="What needs doing" name="title" required />
                    <label class="field">
                      <span>Type</span>
                      <select name="task_type">
                        {['call', 'linkedin', 'email', 'other'].map((type) => (
                          <option key={type} value={type}>
                            {label(type)}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label class="field">
                      <span>Due</span>
                      <input name="due_on" type="date" />
                    </label>
                    <PrimaryButton type="submit">Add follow-up</PrimaryButton>
                  </form>
                </RecordActionMenu>
              </>
            ) : null}
          </div>
        ) : null}

        <section class="record-section" aria-label="Relationship">
          <h2>Relationship</h2>
          <dl class="meta-grid">
            <Fact term="Engagement" value={label(person.engagement_status ?? 'not_contacted')} />
            <Fact term="Source" value={sourceText(person)} />
            <Fact term="Last contacted" value={whenLabel(person.last_contacted_at)} />
            <Fact term="Last reply" value={whenLabel(person.last_replied_at)} />
            <Fact term="Role" value={[person.current_title, person.headline].filter(Boolean).join(' · ')} />
            <Fact term="Location" value={person.city ?? ''} />
          </dl>
          <div class="chip-row" aria-label="Tags">
            {crm.tags.length === 0 ? <span class="mute">No tags</span> : null}
            {crm.tags.map((tag) => (
              <span key={tag.id} class="chip" style={`border-color:${tag.color}`}>
                {tag.name}
                {canEdit ? (
                  <form method="post" action={action} class="inline-form">
                    <input type="hidden" name="intent" value="untag" />
                    <input type="hidden" name="tag_id" value={tag.id} />
                    <button class="btn-link" type="submit" aria-label={`Remove tag ${tag.name}`}>
                      ×
                    </button>
                  </form>
                ) : null}
              </span>
            ))}
          </div>
          {canEdit ? (
            <form method="post" action={action} class="hub-bar">
              <input type="hidden" name="intent" value="tag" />
              <label class="field">
                <span>Add a tag</span>
                <input name="tag_name" list="all-tags" maxLength={60} required />
                <datalist id="all-tags">
                  {crm.allTags.map((tag) => (
                    <option key={tag.id} value={tag.name} />
                  ))}
                </datalist>
              </label>
              <button class="btn btn-ghost btn-small" type="submit">
                Add tag
              </button>
            </form>
          ) : null}
        </section>

        <section class="record-section" aria-label="Activity feed">
          <h2>Activity</h2>
          {crm.feed.length === 0 ? (
            <EmptyState>Nothing has happened with this person yet.</EmptyState>
          ) : (
            <ul class="feed">
              {crm.feed.map((item) => (
                <li key={item.id} class={`feed-item feed-${item.kind}`}>
                  <FeedEntry
                    item={item}
                    action={action}
                    canEdit={canEdit}
                    canSend={canSend}
                    threadSize={item.thread_id ? (threadSizes.get(item.thread_id) ?? 1) : 1}
                  />
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    )
  }
}

function sourceText(person: Person) {
  if (!person.source) return ''
  return [label(person.source), person.source_detail].filter(Boolean).join(' · ')
}

function Fact(handle: Handle<{ term: string; value: string }>) {
  return () => (
    <div class="meta-row">
      <dt>{handle.props.term}</dt>
      <dd>{handle.props.value || '—'}</dd>
    </div>
  )
}

function FeedEntry(
  handle: Handle<{ item: FeedItem; action: string; canEdit: boolean; canSend: boolean; threadSize: number }>,
) {
  return () => {
    let { item, action, canEdit, canSend, threadSize } = handle.props
    let when = whenLabel(item.occurred_at)
    if (item.kind === 'email') {
      let inbound = item.direction === 'inbound'
      let note = item.classification ? ` · ${label(item.classification)}` : ''
      return (
        <article>
          <header>
            <strong>{inbound ? 'Reply received' : 'Email sent'}</strong>
            <span class="hint">
              {' '}
              · {when}
              {note}
              {threadSize > 1 ? ` · thread of ${threadSize}` : ''}
            </span>
          </header>
          <p class="feed-subject">{item.subject}</p>
          {item.body ? <pre class="feed-body">{item.body}</pre> : null}
          {inbound && canSend && item.communication_id && item.classification !== 'bounce' ? (
            <details>
              <summary>Change how this reply is marked</summary>
              <form method="post" action={action} class="hub-bar">
                <input type="hidden" name="communication_id" value={item.communication_id} />
                <label class="field">
                  <span>They replied</span>
                  <select name="classification">
                    {REPLY_LABELS.map((key) => (
                      <option key={key} value={key} selected={item.classification === key}>
                        {label(key)}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-ghost btn-small" type="submit" name="intent" value="classify_reply">
                  Save
                </button>
              </form>
            </details>
          ) : null}
          {inbound && canSend ? (
            <details>
              <summary>Reply</summary>
              <form method="post" action={action} class="form-narrow">
                <input type="hidden" name="thread_id" value={item.thread_id ?? ''} />
                <input type="hidden" name="in_reply_to" value={item.rfc822_message_id ?? ''} />
                <input type="hidden" name="mailbox_id" value={item.mailbox_id ?? ''} />
                <input
                  type="hidden"
                  name="subject"
                  value={item.subject?.match(/^re:/i) ? item.subject : `Re: ${item.subject ?? ''}`}
                />
                <label class="field">
                  <span>Your reply</span>
                  <textarea name="body" rows={4} required />
                </label>
                <button class="btn btn-primary btn-small" type="submit" name="intent" value="message">
                  Send reply
                </button>
              </form>
            </details>
          ) : null}
        </article>
      )
    }
    if (item.kind === 'note') {
      return (
        <article>
          <header>
            <strong>Note{item.pinned ? ' · pinned' : ''}</strong>
            <span class="hint">
              {' '}
              · {when}
              {item.author ? ` · ${item.author}` : ''}
            </span>
          </header>
          <p>{item.body}</p>
          {canEdit && item.note_id ? (
            <form method="post" action={action} class="inline-form">
              <input type="hidden" name="intent" value="pin_note" />
              <input type="hidden" name="note_id" value={item.note_id} />
              <input type="hidden" name="pinned" value={item.pinned ? '0' : '1'} />
              <button class="btn-link" type="submit">
                {item.pinned ? 'Unpin' : 'Pin'}
              </button>
            </form>
          ) : null}
        </article>
      )
    }
    if (item.kind === 'task') {
      let open = item.status === 'open'
      return (
        <article>
          <header>
            <strong>{label(item.type.replace('task.', 'task_'))}</strong>
            <span class="hint">
              {' '}
              · {when}
              {item.due_at ? ` · due ${whenLabel(item.due_at)}` : ''}
            </span>
          </header>
          <p>
            {item.title}
            {item.task_type ? ` (${label(item.task_type)})` : ''}
          </p>
          {open && canEdit && item.task_id ? (
            <form method="post" action={action} class="inline-form">
              <input type="hidden" name="intent" value="complete_task" />
              <input type="hidden" name="task_id" value={item.task_id} />
              <button class="btn btn-ghost btn-small" type="submit">
                Mark done
              </button>
            </form>
          ) : null}
        </article>
      )
    }
    if (item.kind === 'tag') {
      return (
        <article>
          <strong>{item.type === 'person.tagged' ? 'Tagged' : 'Untagged'}</strong>
          <span class="hint">
            {' '}
            · {item.tag} · {when}
          </span>
        </article>
      )
    }
    return (
      <article>
        <strong>{label(item.type.replace(/\./g, '_'))}</strong>
        <span class="hint"> · {when}</span>
      </article>
    )
  }
}
