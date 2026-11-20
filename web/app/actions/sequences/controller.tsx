import { createController } from 'remix/router'

import {
  createSequence,
  enrollInSequence,
  listMailboxes,
  listPeople,
  listSequences,
  sessionFromEnv,
  sessionFromRequest,
} from '../../data/api.ts'
import { redirectWithNotice } from '../../data/auth.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { SequencesIndexPage } from './pages.tsx'
import { sequenceKey } from './steps.ts'

async function load(session: NonNullable<ReturnType<typeof sessionFromEnv>>) {
  const [sequences, people, mailboxes] = await Promise.all([
    listSequences(session),
    listPeople(session),
    listMailboxes(session),
  ])
  return {
    sequences: sequences.data,
    people: people.data,
    mailboxes: mailboxes.data,
  }
}

export default createController(routes.sequencesCreate, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const data = await load(session)
      return context.render(<SequencesIndexPage {...data} orgQuery={orgQuery(context.url)} />)
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? 'create')
      try {
        let notice = 'Saved'
        if (intent === 'create') {
          const name = String(form.get('name') ?? '').trim()
          if (!name) throw new Error('Give the sequence a name.')
          const asTemplate = String(form.get('is_template') ?? '') === 'on'
          const created = await createSequence(session, {
            key: sequenceKey(name, Date.now().toString(36).slice(-4)),
            name,
            shared: true,
            is_template: asTemplate,
          })
          // Straight to the editor: a new sequence is only useful once its steps are written.
          return redirectWithNotice(
            `${routes.sequencesShow.index.href({ sequenceId: created.id })}${orgQuery(context.url)}`,
            `Created ${name}. It starts with one email: change it, or add more steps below.`,
          )
        } else if (intent === 'enroll') {
          const sequenceId = String(form.get('sequence_id') ?? '')
          const personId = String(form.get('person_id') ?? '')
          const mailboxId = String(form.get('mailbox_id') ?? '').trim()
          await enrollInSequence(session, sequenceId, {
            person_id: personId,
            ...(mailboxId ? { mailbox_id: mailboxId } : {}),
          })
          notice = 'Enrolled — first step sent'
        }
        const data = await load(session)
        return context.render(
          <SequencesIndexPage {...data} orgQuery={orgQuery(context.url)} notice={notice} />,
        )
      } catch (error) {
        const data = await load(session)
        return context.render(
          <SequencesIndexPage
            {...data}
            orgQuery={orgQuery(context.url)}
            notice={`Error: ${String(error)}`}
          />,
        )
      }
    },
  },
})
