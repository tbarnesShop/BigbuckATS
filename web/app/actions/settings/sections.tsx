import type { Handle } from 'remix/component'

import type {
  ApplicationFormPayload,
  CalendarConnection,
  ImportRun,
  InboxMessage,
  Mailbox,
  MessageTemplate,
  WebhookEndpoint,
} from '../../data/api.ts'
import type { CustomFieldDefinitionsQuery } from '../../graphql/generated.ts'
import { routes } from '../../routes.ts'
import { EmptyState, Field, PrimaryButton, Shell } from '../../ui/shell.tsx'
import { label, readableMergeFields, statusTone, whenLabel } from '../../data/labels.ts'
import { signedIn } from '../../data/auth.ts'

type FieldDef = CustomFieldDefinitionsQuery['customFieldDefinitions'][number]

const STANDARD = ['display_name', 'email', 'phone', 'linkedin', 'links', 'country', 'region'] as const
const STANDARD_LABELS: Record<(typeof STANDARD)[number], string> = {
  display_name: 'Full name',
  email: 'Email',
  phone: 'Phone',
  linkedin: 'LinkedIn',
  links: 'Portfolio or other links',
  country: 'Country',
  region: 'Region',
}

/** "de" → "German version": a translated template, not a duplicate of the English one. */
function languageVersion(locale: string) {
  try {
    const name = new Intl.DisplayNames(['en'], { type: 'language' }).of(locale)
    return name ? `${name} version` : locale.toUpperCase()
  } catch {
    return locale.toUpperCase()
  }
}

function Frame(
  handle: Handle<{
    title: string
    children?: import('remix/component').RemixNode
    notice?: string
    error?: string
    requiredDraft?: string[]
    screeningDraft?: string[]
  }>,
) {
  return () => (
    <Shell
      title={handle.props.title}
      eyebrow="Settings"
      backHref={routes.settingsIndex.href()}
      backLabel="Settings"
    >
      {handle.props.error ? (
        <p class="notice-bad" role="alert">
          {handle.props.error}
        </p>
      ) : null}
      {handle.props.notice ? (
        <p class="notice" role="status">
          {handle.props.notice}
        </p>
      ) : null}
      {handle.props.children}
    </Shell>
  )
}

export function TemplatesPage(
  handle: Handle<{
    templates: MessageTemplate[]
    notice?: string
    error?: string
    values?: Record<string, string>
  }>,
) {
  return () => {
    let { templates, notice, error } = handle.props
    let action = routes.settingsTemplates.action.href()
    return (
      <Frame title="Templates" notice={notice} error={error}>
        {templates.length === 0 ? (
          <EmptyState>No active templates. Create one to reuse outreach copy.</EmptyState>
        ) : (
          <ul class="queue">
            {templates.map((template) => (
              <li key={template.id} class="queue-item settings-row">
                <div class="body">
                  <span class="title">
                    {template.subject ? readableMergeFields(template.subject) : label(template.key)}
                  </span>
                  <span class="hint">
                    {template.key}
                    {template.locale && template.locale !== 'en'
                      ? ` · ${languageVersion(template.locale)}`
                      : ''}
                    {template.message_type ? ` · ${label(template.message_type)}` : ''}
                  </span>
                </div>
                <details class="settings-edit">
                  <summary class="btn btn-ghost btn-small">View or edit</summary>
                  <form method="post" action={action} class="form-narrow">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={template.id} />
                    <Field label="Subject" name="subject" defaultValue={template.subject ?? ''} required />
                    <label class="field">
                      <span>Body</span>
                      <textarea name="body" rows={8} required defaultValue={template.body ?? ''} />
                    </label>
                    <p class="sub">
                      Merge fields such as {'{{ person.first_name }}'} are filled in when the message is sent.
                    </p>
                    <button class="btn btn-primary btn-small" type="submit">
                      Save changes
                    </button>
                  </form>
                  <form method="post" action={action}>
                    <input type="hidden" name="intent" value="archive" />
                    <input type="hidden" name="id" value={template.id} />
                    <button class="btn btn-ghost btn-small" type="submit">
                      Archive template
                    </button>
                  </form>
                </details>
              </li>
            ))}
          </ul>
        )}
        <form method="post" action={action} class="form-narrow">
          <input type="hidden" name="intent" value="create" />
          <h2>New template</h2>
          <Field
            defaultValue={handle.props.values?.['key']}
            label="Key (for example offer-follow-up)"
            name="key"
            required
          />
          <Field defaultValue={handle.props.values?.['subject']} label="Subject" name="subject" required />
          <label class="field">
            <span>Body</span>
            <textarea name="body" rows={5} required defaultValue={handle.props.values?.body} />
          </label>
          <PrimaryButton type="submit">Save template</PrimaryButton>
        </form>
      </Frame>
    )
  }
}

export function ApplicationFormPage(
  handle: Handle<{
    form: ApplicationFormPayload
    fields: FieldDef[]
    notice?: string
    error?: string
    requiredDraft?: string[]
    screeningDraft?: string[]
  }>,
) {
  return () => {
    let { form, fields, notice, error } = handle.props
    let screening = new Set(
      handle.props.screeningDraft ?? form.screening_questions.map((question) => question.id),
    )
    let required = new Set(handle.props.requiredDraft ?? form.required_fields)
    return (
      <Frame title="Application form" notice={notice} error={error}>
        <p class="sub mute">
          Name and email stay required. Screening questions are application fields shown on apply.
        </p>
        <form method="post" action={routes.settingsForm.action.href()} class="form-narrow">
          <fieldset>
            <legend>Required on the apply form</legend>
            <p class="sub">
              Phone, LinkedIn and links always appear as optional fields; tick them to make them required.
            </p>
            {STANDARD.map((key) => (
              <label key={key} class="field">
                <span>
                  <input
                    type="checkbox"
                    name="required_fields"
                    value={key}
                    defaultChecked={required.has(key) || key === 'display_name' || key === 'email'}
                    disabled={key === 'display_name' || key === 'email'}
                  />{' '}
                  {STANDARD_LABELS[key]}
                </span>
              </label>
            ))}
            <input type="hidden" name="required_fields" value="display_name" />
            <input type="hidden" name="required_fields" value="email" />
          </fieldset>
          <fieldset>
            <legend>Screening questions</legend>
            {fields.filter((field) => field.status === 'active').length === 0 ? (
              <p class="sub">
                No application custom fields yet. Add one under Custom fields, then come back.
              </p>
            ) : (
              fields
                .filter((field) => field.status === 'active')
                .map((field) => (
                  <label key={field.id} class="field">
                    <span>
                      <input
                        type="checkbox"
                        name="screening_field_ids"
                        value={field.id}
                        defaultChecked={screening.has(field.id)}
                      />{' '}
                      {field.label}
                    </span>
                  </label>
                ))
            )}
          </fieldset>
          <PrimaryButton type="submit">Save form</PrimaryButton>
        </form>
      </Frame>
    )
  }
}

export function MailboxesPage(handle: Handle<{ mailboxes: Mailbox[]; error?: string; notice?: string }>) {
  return () => {
    let { mailboxes, error, notice } = handle.props
    let action = routes.settingsMailboxes.action.href()
    let canManage = signedIn()?.permissions?.includes('mailbox.manage') ?? false
    let canConnect = signedIn()?.permissions?.includes('mailbox.connect') ?? false
    return (
      <Frame title="Mailboxes" error={error} notice={notice}>
        <p class="sub mute">Inboxes used for recruiting messages. Only a connected mailbox sends.</p>
        {canConnect ? (
          <form method="post" action={action} class="hub-bar">
            <input type="hidden" name="intent" value="create_test" />
            <Field label="Test mailbox address" name="email" email required />
            <PrimaryButton type="submit">Add Test mailbox</PrimaryButton>
            <span class="hint">
              A Test mailbox sends and receives inside Bigbuck. Nothing leaves the product, so you can try a
              whole sequence, replies and bounces included.
            </span>
          </form>
        ) : null}
        {mailboxes.length === 0 ? (
          <EmptyState>No mailbox is connected yet.</EmptyState>
        ) : (
          <ul class="queue">
            {mailboxes.map((mailbox) => (
              <li key={mailbox.id} class="queue-item">
                <div class="body">
                  <span class="title">{mailbox.email}</span>
                  <span class="hint">
                    {mailbox.provider === 'sandbox' ? 'Test mailbox · ' : `${label(mailbox.kind)} · `}
                    <span class={statusTone(mailbox.status)}>{label(mailbox.status)}</span>
                    {typeof mailbox.daily_cap === 'number'
                      ? ` · ${mailbox.sent_today ?? 0} of ${mailbox.daily_cap} sent today`
                      : ''}
                  </span>
                </div>
                {mailbox.provider === 'sandbox' ? (
                  <a
                    class="btn btn-ghost btn-small"
                    href={routes.settingsMailboxInbox.index.href({ id: mailbox.id })}
                  >
                    Open Test inbox
                  </a>
                ) : null}
                {canManage ? (
                  <details class="settings-edit">
                    <summary class="btn btn-ghost btn-small">Manage</summary>
                    <form method="post" action={action} class="hub-bar">
                      <input type="hidden" name="id" value={mailbox.id} />
                      <input type="hidden" name="intent" value="cap" />
                      <label class="field">
                        <span>Daily sending cap</span>
                        <input
                          name="daily_cap"
                          type="number"
                          min="1"
                          max="10000"
                          defaultValue={String(mailbox.daily_cap ?? 2000)}
                        />
                      </label>
                      <button class="btn btn-primary btn-small" type="submit">
                        Save cap
                      </button>
                    </form>
                    <form method="post" action={action} class="row-actions">
                      <input type="hidden" name="id" value={mailbox.id} />
                      <input type="hidden" name="intent" value="status" />
                      {mailbox.status === 'connected' ? (
                        <button class="btn btn-ghost btn-small" type="submit" name="status" value="paused">
                          Pause sending
                        </button>
                      ) : null}
                      {mailbox.status === 'paused' || mailbox.status === 'disconnected' ? (
                        <button class="btn btn-ghost btn-small" type="submit" name="status" value="connected">
                          Resume sending
                        </button>
                      ) : null}
                      {mailbox.status !== 'disconnected' ? (
                        <button
                          class="btn btn-ghost btn-small"
                          type="submit"
                          name="status"
                          value="disconnected"
                        >
                          Disconnect
                        </button>
                      ) : null}
                    </form>
                  </details>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </Frame>
    )
  }
}

export function CalendarPage(
  handle: Handle<{
    connections: CalendarConnection[]
    notice?: string
    error?: string
    values?: Record<string, string>
  }>,
) {
  return () => {
    let { connections, notice, error } = handle.props
    return (
      <Frame title="Calendar" notice={notice} error={error}>
        <p class="sub mute">Connect an authorized calendar to coordinate interviews.</p>
        {connections.length === 0 ? (
          <EmptyState>No calendars connected.</EmptyState>
        ) : (
          <ul class="queue">
            {connections.map((connection) => (
              <li key={connection.id} class="queue-item">
                <div class="body">
                  <span class="title">{connection.calendar_id || connection.id}</span>
                  <span class="hint">
                    {connection.kind || 'calendar'} · {connection.status || 'connected'}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        )}
        <form method="post" action={routes.settingsCalendar.action.href()} class="form-narrow">
          <Field
            defaultValue={handle.props.values?.['calendar_id']}
            label="Calendar id"
            name="calendar_id"
            required
          />
          <Field
            defaultValue={handle.props.values?.['secret_ref']}
            label="Secret reference"
            name="secret_ref"
            required
          />
          <PrimaryButton type="submit">Connect calendar</PrimaryButton>
        </form>
      </Frame>
    )
  }
}

export function ImportPage(
  handle: Handle<{ runs: ImportRun[]; notice?: string; error?: string; values?: Record<string, string> }>,
) {
  return () => {
    let { runs, notice, error } = handle.props
    return (
      <Frame title="Import" notice={notice} error={error}>
        <p class="sub mute">Paste a people CSV. Dry-run is on unless you turn it off.</p>
        <form method="post" action={routes.settingsImport.action.href()} class="form-narrow">
          <label class="field">
            <span>CSV</span>
            <textarea
              name="csv"
              rows={8}
              required
              defaultValue={handle.props.values?.csv ?? 'display_name,email\nAda Lovelace,ada@example.com'}
            />
          </label>
          <label class="field">
            <span>
              <input
                type="checkbox"
                name="dry_run"
                value="1"
                defaultChecked={handle.props.values ? handle.props.values.dry_run === '1' : true}
              />{' '}
              Dry run
            </span>
          </label>
          <PrimaryButton type="submit">Import</PrimaryButton>
        </form>
        {runs.length === 0 ? null : (
          <div class="table-wrap" role="region" aria-label="Import history" tabIndex={0}>
            <table class="table">
              <thead>
                <tr>
                  <th>When</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Errors</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr key={run.id}>
                    <td>{run.created_at?.slice(0, 16) ?? run.id.slice(0, 8)}</td>
                    <td>{label(run.status)}</td>
                    <td>{run.created_count ?? 0}</td>
                    <td>{run.error_count ?? 0}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Frame>
    )
  }
}

const WEBHOOK_EVENTS = [
  ['application.created', 'Application created'],
  ['application.moved', 'Candidate moved stage'],
  ['application.hire', 'Candidate hired'],
  ['application.reject', 'Application rejected'],
  ['application.withdraw', 'Application withdrawn'],
  ['offer.approved', 'Offer approved'],
  ['offer.sent', 'Offer sent'],
  ['offer.accepted', 'Offer accepted'],
  ['offer.declined', 'Offer declined'],
  ['person.created', 'Person created'],
  ['job.created', 'Job created'],
  ['interview.scheduled', 'Interview scheduled'],
] as const

export function WebhooksPage(
  handle: Handle<{
    webhooks: WebhookEndpoint[]
    notice?: string
    error?: string
    values?: Record<string, string>
  }>,
) {
  return () => {
    let { webhooks, notice, error } = handle.props
    return (
      <Frame title="Webhooks" notice={notice} error={error}>
        <p class="sub mute">
          We send a signed POST for each event. URLs must be HTTPS; private and metadata addresses are
          refused. Each webhook gets its own signing secret, shown once when it is created or rotated.
        </p>
        {webhooks.length === 0 ? (
          <EmptyState>No webhooks yet.</EmptyState>
        ) : (
          <ul class="queue">
            {webhooks.map((hook) => (
              <li key={hook.id} class="queue-item settings-row">
                <div class="body">
                  <span class="title">
                    {hook.key}{' '}
                    <span class={hook.active ? 'chip chip-ok' : 'chip'}>{hook.active ? 'On' : 'Off'}</span>
                  </span>
                  <span class="hint">{hook.url}</span>
                  <span class="hint">
                    {hook.event_types?.length
                      ? `Events: ${hook.event_types.map((event) => label(event.replace(/\./g, '_'))).join(', ')}`
                      : 'All events'}
                  </span>
                  {hook.signing_secret ? (
                    <p class="notice" role="status">
                      Signing secret (copy it now, it is not shown again): <code>{hook.signing_secret}</code>
                    </p>
                  ) : null}
                </div>
                <details class="settings-edit">
                  <summary class="btn btn-ghost btn-small">Edit and deliveries</summary>
                  <form method="post" action={routes.settingsWebhooks.action.href()} class="form-narrow">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={hook.id} />
                    <Field label="HTTPS URL" name="url" defaultValue={hook.url} required />
                    <fieldset>
                      <legend>Events (none ticked = all events)</legend>
                      {[
                        ...WEBHOOK_EVENTS,
                        ...(hook.event_types ?? [])
                          .filter((event) => !WEBHOOK_EVENTS.some(([value]) => value === event))
                          .map((event) => [event, label(event.replace(/\./g, '_'))] as const),
                      ].map(([value, text]) => (
                        <label key={value} class="field">
                          <span>
                            <input
                              type="checkbox"
                              name="event_types"
                              value={value}
                              defaultChecked={(hook.event_types ?? []).includes(value)}
                            />{' '}
                            {text}
                          </span>
                        </label>
                      ))}
                    </fieldset>
                    <label class="field">
                      <span>Delivery</span>
                      <select name="active">
                        <option value="true" selected={hook.active}>
                          On
                        </option>
                        <option value="false" selected={!hook.active}>
                          Off
                        </option>
                      </select>
                    </label>
                    <button class="btn btn-primary btn-small" type="submit">
                      Save webhook
                    </button>
                  </form>
                  <form method="post" action={routes.settingsWebhooks.action.href()}>
                    <input type="hidden" name="intent" value="rotate" />
                    <input type="hidden" name="id" value={hook.id} />
                    <button class="btn btn-ghost btn-small" type="submit">
                      Rotate signing secret
                    </button>
                  </form>
                  <h3>Recent deliveries</h3>
                  {hook.recent_deliveries?.length ? (
                    <div class="table-wrap" role="region" aria-label={`${hook.key} deliveries`} tabIndex={0}>
                      <table class="table">
                        <thead>
                          <tr>
                            <th>Event</th>
                            <th>Status</th>
                            <th>Attempts</th>
                            <th>Response</th>
                            <th>When</th>
                          </tr>
                        </thead>
                        <tbody>
                          {hook.recent_deliveries.map((row) => (
                            <tr key={row.id}>
                              <td>{label(row.event_type.replace(/\./g, '_'))}</td>
                              <td>
                                <span class={statusTone(row.status)}>{label(row.status)}</span>
                              </td>
                              <td>{row.attempt_count}</td>
                              <td>{row.response_status ?? row.last_error ?? '—'}</td>
                              <td>{whenLabel(row.delivered_at ?? row.created_at)}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  ) : (
                    <p class="sub">No deliveries yet.</p>
                  )}
                </details>
              </li>
            ))}
          </ul>
        )}
        <form method="post" action={routes.settingsWebhooks.action.href()} class="form-narrow">
          <Field defaultValue={handle.props.values?.['key']} label="Key" name="key" required />
          <input type="hidden" name="intent" value="create" />
          <Field defaultValue={handle.props.values?.['url']} label="HTTPS URL" name="url" required />
          <PrimaryButton type="submit">Add webhook</PrimaryButton>
        </form>
      </Frame>
    )
  }
}

export function MailboxInboxPage(
  handle: Handle<{ mailbox: Mailbox; messages: InboxMessage[]; error?: string; notice?: string }>,
) {
  return () => {
    let { mailbox, messages, error, notice } = handle.props
    let action = routes.settingsMailboxInbox.action.href({ id: mailbox.id })
    let canManage = signedIn()?.permissions?.includes('mailbox.manage') ?? false
    return (
      <Frame title="Test inbox" error={error} notice={notice}>
        <p class="sub mute">
          {mailbox.email} · mail sent from this Test mailbox lands here. Answer it as the candidate would.
        </p>
        {messages.length === 0 ? (
          <EmptyState>Nothing sent yet. Enroll someone in a sequence from this mailbox.</EmptyState>
        ) : (
          <ul class="queue">
            {messages.map((message) => (
              <li key={message.id} class="queue-item">
                <div class="body">
                  <span class="title">{message.subject || '(no subject)'}</span>
                  <span class="hint">
                    {message.direction === 'outbound'
                      ? `To ${message.to_address}`
                      : `From ${message.from_address}`}
                    {' · '}
                    {whenLabel(message.delivered_at)}
                    {message.direction === 'outbound'
                      ? message.answered
                        ? ' · Answered'
                        : ' · Waiting for an answer'
                      : ''}
                  </span>
                </div>
                {canManage && message.direction === 'outbound' ? (
                  <form method="post" action={action} class="row-actions">
                    <input type="hidden" name="message_id" value={message.id} />
                    <button class="btn btn-ghost btn-small" type="submit" name="kind" value="reply">
                      Reply
                    </button>
                    <button class="btn btn-ghost btn-small" type="submit" name="kind" value="auto_reply">
                      Out of office
                    </button>
                    <button class="btn btn-ghost btn-small" type="submit" name="kind" value="bounce">
                      Bounce
                    </button>
                  </form>
                ) : null}
              </li>
            ))}
          </ul>
        )}
        <p>
          <a href={routes.settingsMailboxes.index.href()}>Back to mailboxes</a>
        </p>
      </Frame>
    )
  }
}
