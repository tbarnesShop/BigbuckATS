import { createController } from 'remix/router'

import {
  archiveMessageTemplate,
  createCalendarConnection,
  createTestMailbox,
  listMailboxMessages,
  simulateMailboxReply,
  createImport,
  createMessageTemplate,
  createWebhook,
  getApplicationForm,
  listCalendarConnections,
  listImports,
  listMailboxes,
  listMessageTemplates,
  listWebhooks,
  sessionFromRequest,
  updateApplicationForm,
  rotateWebhookSecret,
  updateMailbox,
  updateMessageTemplate,
  updateWebhook,
  type WebhookEndpoint,
} from '../../data/api.ts'
import { gql } from '../../data/graphql.ts'
import type { CustomFieldDefinitionsQuery } from '../../graphql/generated.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import {
  ApplicationFormPage,
  CalendarPage,
  ImportPage,
  MailboxesPage,
  MailboxInboxPage,
  TemplatesPage,
  WebhooksPage,
} from './sections.tsx'

function formValues(form: FormData) {
  return Object.fromEntries(
    ['key', 'subject', 'body', 'calendar_id', 'csv', 'dry_run', 'url'].map((key) => [
      key,
      String(form.get(key) ?? ''),
    ]),
  )
}

function message(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

export const templatesController = createController(routes.settingsTemplates, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listMessageTemplates(session)
        return context.render(<TemplatesPage templates={data} />)
      } catch (error) {
        return context.render(<TemplatesPage templates={[]} error={message(error)} />)
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? 'create')
      try {
        let notice = 'Saved.'
        if (intent === 'archive') {
          await archiveMessageTemplate(session, String(form.get('id') ?? ''))
          notice = 'Template archived.'
        } else if (intent === 'update') {
          const subject = String(form.get('subject') ?? '').trim()
          const body = String(form.get('body') ?? '')
          if (!subject || !body.trim()) throw new Error('A template needs a subject and a body.')
          await updateMessageTemplate(session, String(form.get('id') ?? ''), { subject, body })
          notice = 'Template updated.'
        } else {
          await createMessageTemplate(session, {
            key: String(form.get('key') ?? '').trim(),
            subject: String(form.get('subject') ?? '').trim(),
            body: String(form.get('body') ?? ''),
            message_type: 'outreach',
          })
        }
        const { data } = await listMessageTemplates(session)
        return context.render(<TemplatesPage templates={data} notice={notice} />)
      } catch (error) {
        const data = await listMessageTemplates(session).catch(() => ({ data: [] }))
        return context.render(
          <TemplatesPage values={formValues(form)} templates={data.data} error={message(error)} />,
        )
      }
    },
  },
})

export const applicationFormController = createController(routes.settingsForm, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const [form, fields] = await Promise.all([
          getApplicationForm(session),
          gql<CustomFieldDefinitionsQuery, { entity: string }>(session, 'CustomFieldDefinitions', {
            entity: 'application',
          }).catch(() => ({ customFieldDefinitions: [] })),
        ])
        return context.render(<ApplicationFormPage form={form} fields={fields.customFieldDefinitions} />)
      } catch (error) {
        return context.render(
          <ApplicationFormPage
            form={{
              required_fields: ['display_name', 'email'],
              standard_fields: [],
              screening_questions: [],
            }}
            fields={[]}
            error={message(error)}
          />,
        )
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const formData = await context.request.formData()
      const required = [...new Set(formData.getAll('required_fields').map(String).filter(Boolean))]
      const screening = formData.getAll('screening_field_ids').map(String).filter(Boolean)
      try {
        const form = await updateApplicationForm(session, {
          required_fields: required,
          screening_field_ids: screening,
        })
        const fields = await gql<CustomFieldDefinitionsQuery, { entity: string }>(
          session,
          'CustomFieldDefinitions',
          {
            entity: 'application',
          },
        ).catch(() => ({ customFieldDefinitions: [] }))
        return context.render(
          <ApplicationFormPage
            form={form}
            fields={fields.customFieldDefinitions}
            notice="Application form saved."
          />,
        )
      } catch (error) {
        const form = await getApplicationForm(session).catch(() => ({
          required_fields: required,
          standard_fields: [],
          screening_questions: [],
        }))
        const fields = await gql<CustomFieldDefinitionsQuery, { entity: string }>(
          session,
          'CustomFieldDefinitions',
          { entity: 'application' },
        ).catch(() => ({ customFieldDefinitions: [] }))
        return context.render(
          <ApplicationFormPage
            form={form}
            fields={fields.customFieldDefinitions}
            requiredDraft={required}
            screeningDraft={screening}
            error={message(error)}
          />,
        )
      }
    },
  },
})

export const mailboxesController = createController(routes.settingsMailboxes, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listMailboxes(session)
        return context.render(<MailboxesPage mailboxes={data} />)
      } catch (error) {
        return context.render(<MailboxesPage mailboxes={[]} error={message(error)} />)
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const id = String(form.get('id') ?? '')
      const reload = async () => (await listMailboxes(session).catch(() => ({ data: [] }))).data
      if (String(form.get('intent') ?? '') === 'create_test') {
        try {
          await createTestMailbox(session, String(form.get('email') ?? '').trim())
          return context.render(<MailboxesPage mailboxes={await reload()} notice="Test mailbox added." />)
        } catch (error) {
          return context.render(<MailboxesPage mailboxes={await reload()} error={message(error)} />)
        }
      }
      try {
        if (form.get('intent') === 'cap') {
          const cap = Number(form.get('daily_cap'))
          if (!Number.isInteger(cap) || cap < 1 || cap > 10000)
            throw new Error('The daily cap must be between 1 and 10,000.')
          await updateMailbox(session, id, { daily_cap: cap })
          return context.render(<MailboxesPage mailboxes={await reload()} notice="Daily cap saved." />)
        }
        const status = String(form.get('status') ?? '')
        if (!['connected', 'paused', 'disconnected'].includes(status))
          throw new Error('Choose pause, resume or disconnect.')
        await updateMailbox(session, id, { status })
        const notices: Record<string, string> = {
          connected: 'Sending resumed.',
          paused: 'Sending paused. Sequences and messages from this mailbox wait until you resume.',
          disconnected: 'Mailbox disconnected.',
        }
        return context.render(<MailboxesPage mailboxes={await reload()} notice={notices[status]} />)
      } catch (error) {
        return context.render(<MailboxesPage mailboxes={await reload()} error={message(error)} />)
      }
    },
  },
})

export const calendarController = createController(routes.settingsCalendar, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listCalendarConnections(session)
        return context.render(<CalendarPage connections={data} />)
      } catch (error) {
        return context.render(<CalendarPage connections={[]} error={message(error)} />)
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const secret = String(form.get('secret_ref') ?? '').trim()
      const calendarId = String(form.get('calendar_id') ?? '').trim()
      const reload = async () => (await listCalendarConnections(session).catch(() => ({ data: [] }))).data
      if (!secret || secret === 'sm://demo') {
        return context.render(
          <CalendarPage
            values={formValues(form)}
            connections={await reload()}
            error="Use a real calendar grant. sm://demo is not a connection."
          />,
        )
      }
      try {
        await createCalendarConnection(session, { calendar_id: calendarId, secret_ref: secret })
        return context.render(<CalendarPage connections={await reload()} notice="Calendar connected." />)
      } catch (error) {
        return context.render(
          <CalendarPage values={formValues(form)} connections={await reload()} error={message(error)} />,
        )
      }
    },
  },
})

export const importController = createController(routes.settingsImport, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listImports(session)
        return context.render(<ImportPage runs={data} />)
      } catch (error) {
        return context.render(<ImportPage runs={[]} error={message(error)} />)
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const reload = async () => (await listImports(session).catch(() => ({ data: [] }))).data
      try {
        await createImport(session, {
          csv: String(form.get('csv') ?? ''),
          dry_run: form.get('dry_run') === '1',
        })
        return context.render(<ImportPage runs={await reload()} notice="Import finished." />)
      } catch (error) {
        return context.render(
          <ImportPage values={formValues(form)} runs={await reload()} error={message(error)} />,
        )
      }
    },
  },
})

export const webhooksController = createController(routes.settingsWebhooks, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listWebhooks(session)
        return context.render(<WebhooksPage webhooks={data} />)
      } catch (error) {
        return context.render(<WebhooksPage webhooks={[]} error={message(error)} />)
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const url = String(form.get('url') ?? '').trim()
      const intent = String(form.get('intent') ?? 'create')
      const id = String(form.get('id') ?? '')
      const reload = async () => (await listWebhooks(session).catch(() => ({ data: [] }))).data
      // Show a freshly issued signing secret once, on the webhook it belongs to.
      const withSecret = async (hook: WebhookEndpoint) =>
        (await reload()).map((row) =>
          row.id === hook.id ? { ...row, signing_secret: hook.signing_secret } : row,
        )
      if (intent === 'rotate' || intent === 'update') {
        try {
          if (intent === 'rotate') {
            const rotated = await rotateWebhookSecret(session, id)
            return context.render(
              <WebhooksPage webhooks={await withSecret(rotated)} notice="Signing secret rotated." />,
            )
          }
          if (!url.startsWith('https://')) throw new Error('Webhook URL must be https.')
          await updateWebhook(session, id, {
            url,
            event_types: form.getAll('event_types').map(String),
            active: form.get('active') !== 'false',
          })
          return context.render(<WebhooksPage webhooks={await reload()} notice="Webhook saved." />)
        } catch (error) {
          return context.render(<WebhooksPage webhooks={await reload()} error={message(error)} />)
        }
      }
      if (!url.startsWith('https://')) {
        return context.render(
          <WebhooksPage
            values={formValues(form)}
            webhooks={await reload()}
            error="Webhook URL must be https."
          />,
        )
      }
      try {
        const created = await createWebhook(session, { key: String(form.get('key') ?? '').trim(), url })
        return context.render(<WebhooksPage webhooks={await withSecret(created)} notice="Webhook added." />)
      } catch (error) {
        return context.render(
          <WebhooksPage values={formValues(form)} webhooks={await reload()} error={message(error)} />,
        )
      }
    },
  },
})

export const mailboxInboxController = createController(routes.settingsMailboxInbox, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const id = context.params.id
      try {
        const [{ data: mailboxes }, { data: messages }] = await Promise.all([
          listMailboxes(session),
          listMailboxMessages(session, id),
        ])
        const mailbox = mailboxes.find((row) => row.id === id)
        if (!mailbox) throw new Error('Mailbox not found')
        return context.render(<MailboxInboxPage mailbox={mailbox} messages={messages} />)
      } catch (error) {
        return context.render(
          <MailboxInboxPage
            mailbox={{ id, kind: '', email: '', status: '' }}
            messages={[]}
            error={message(error)}
          />,
        )
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const id = context.params.id
      const form = await context.request.formData()
      const kindValue = String(form.get('kind') ?? 'reply')
      const kind = kindValue === 'bounce' || kindValue === 'auto_reply' ? kindValue : 'reply'
      let notice: string | undefined
      let failure: string | undefined
      try {
        await simulateMailboxReply(session, id, String(form.get('message_id') ?? ''), kind)
        notice = {
          reply: 'Reply delivered.',
          auto_reply: 'Out-of-office delivered.',
          bounce: 'Bounce delivered.',
        }[kind]
      } catch (error) {
        failure = message(error)
      }
      const [{ data: mailboxes }, { data: messages }] = await Promise.all([
        listMailboxes(session).catch(() => ({ data: [] })),
        listMailboxMessages(session, id).catch(() => ({ data: [] })),
      ])
      const mailbox = mailboxes.find((row) => row.id === id) ?? { id, kind: '', email: '', status: '' }
      return context.render(
        <MailboxInboxPage mailbox={mailbox} messages={messages} notice={notice} error={failure} />,
      )
    },
  },
})
