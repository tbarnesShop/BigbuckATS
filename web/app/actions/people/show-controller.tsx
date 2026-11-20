import { createController } from 'remix/router'

import {
  classifyReply,
  REPLY_LABELS,
  createAffiliation,
  updatePerson,
  replacePersonResume,
  getApplication,
  erasePerson,
  getPerson,
  getPersonTimeline,
  listAffiliations,
  listApplications,
  listApplicationTransitions,
  listCompanies,
  listEnrollments,
  listProjectMembers,
  sendCommunication,
  addPersonNote,
  createFollowUp,
  completeFollowUp,
  getPersonFeed,
  listMailboxes,
  listMessageTemplates,
  listPersonTags,
  listTags,
  pinPersonNote,
  previewPersonMessage,
  tagPerson,
  untagPerson,
  sessionFromEnv,
  sessionFromRequest,
  listJobs,
  createApplication,
} from '../../data/api.ts'
import { loadPersonDocuments } from '../../data/documents.ts'
import { loadCandidateWorkspace, type CandidateWorkspaceState } from '../../data/candidate-workspace.ts'
import {
  runApplicationAction,
  applicationActionPermission,
  type ApplicationActionResult,
} from '../applications/controller.tsx'
import { workflowError, type BookingDraft } from '../../data/application-workflow.ts'
import { personWorkspaceHref, personTab } from '../../data/person-workspace.ts'
import { label } from '../../data/labels.ts'
import { redirectWithNotice, takeWorkflowNotice, signedIn } from '../../data/auth.ts'
import { listReturn } from '../../data/record-return.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { notFound } from '../../ui/not-found.tsx'
import { SetupNeeded } from '../../ui/shell.tsx'
import { gql } from '../../data/graphql.ts'
import type { PersonCustomFieldsQuery } from '../../graphql/generated.ts'
import type { PersonCrm } from './activity.tsx'
import { PersonShowPage } from './pages.tsx'

async function loadPerson(
  session: NonNullable<ReturnType<typeof sessionFromEnv>>,
  personId: string,
  tab = 'applications',
) {
  const permissions = signedIn()?.permissions ?? []
  const [person, apps, memberships, enrollments, affiliations, companies, timeline, custom, documents] =
    await Promise.all([
      getPerson(session, personId),
      permissions.includes('application.read')
        ? listApplications(session, { personId })
        : Promise.resolve({ data: [] }),
      permissions.includes('project.read')
        ? listProjectMembers(session, { personId })
        : Promise.resolve({ data: [] }),
      permissions.includes('sequence.read')
        ? listEnrollments(session, personId)
        : Promise.resolve({ data: [] }),
      listAffiliations(session, personId),
      listCompanies(session),
      getPersonTimeline(session, personId),
      gql<PersonCustomFieldsQuery, { id: string }>(session, 'PersonCustomFields', { id: personId }).catch(
        () => null,
      ),
      loadPersonDocuments(session, personId),
    ])
  // Jobs this person could still be added to (for "Add to a job").
  const openJobs = permissions.includes('application.create')
    ? await listJobs(session)
        .then((result) =>
          result.data
            .filter(
              (job) =>
                job.status === 'active' &&
                !apps.data.some((app) => app.job_id === job.id && app.status === 'active'),
            )
            .map((job) => ({ id: job.id, title: job.title })),
        )
        .catch(() => [])
    : []
  const applicationReasons = Object.fromEntries(
    await Promise.all(
      apps.data
        .filter((application) => ['rejected', 'withdrawn'].includes(application.status))
        .map(async (application) => {
          const history = await listApplicationTransitions(session, application.id).catch(() => ({
            data: [],
          }))
          const closed = history.data.findLast((transition) =>
            ['reject', 'withdraw'].includes(transition.command),
          )
          return [application.id, closed?.reason ?? '']
        }),
    ),
  )
  const workspaces: Record<string, CandidateWorkspaceState> = {}
  if (tab === 'applications')
    await Promise.all(
      apps.data.map(async (app) => {
        try {
          workspaces[app.id] = { status: 'ready', data: await loadCandidateWorkspace(session, app.id) }
        } catch {
          workspaces[app.id] = { status: 'failed' }
        }
      }),
    )
  const crm: PersonCrm | undefined =
    tab === 'activity' ? await loadCrm(session, personId, permissions) : undefined
  return {
    crm,
    openJobs,
    applicationReasons,
    workspaces,
    person,
    documents,
    applications: apps.data,
    memberships: memberships.data,
    enrollments: enrollments.data,
    affiliations: affiliations.data,
    companies: companies.data,
    timeline: timeline.data,
    customFields: custom?.person?.customFields ?? [],
  }
}

async function loadCrm(
  session: NonNullable<ReturnType<typeof sessionFromEnv>>,
  personId: string,
  permissions: string[],
): Promise<PersonCrm> {
  const canSend = permissions.includes('communication.send')
  const [feed, tags, allTags, templates, mailboxes] = await Promise.all([
    getPersonFeed(session, personId).then(
      (r) => r.data,
      () => [],
    ),
    listPersonTags(session, personId).then(
      (r) => r.data,
      () => [],
    ),
    listTags(session).then(
      (r) => r.data,
      () => [],
    ),
    canSend
      ? listMessageTemplates(session).then(
          (r) => r.data.filter((t) => t.status !== 'archived'),
          () => [],
        )
      : [],
    canSend
      ? listMailboxes(session).then(
          (r) => r.data,
          () => [],
        )
      : [],
  ])
  return { feed, tags, allTags, templates, mailboxes }
}

function draftOf(form: FormData): Record<string, string> {
  return Object.fromEntries(
    ['subject', 'body', 'template_key', 'mailbox_id', 'thread_id', 'in_reply_to'].map((key) => [
      key,
      String(form.get(key) ?? ''),
    ]),
  )
}

function composeInput(form: FormData) {
  const text = (key: string) => String(form.get(key) ?? '').trim() || undefined
  return {
    subject: text('subject'),
    body: text('body'),
    template_key: text('template_key'),
    mailbox_id: text('mailbox_id'),
    thread_id: text('thread_id'),
    in_reply_to: text('in_reply_to'),
  }
}

export default createController(routes.peopleShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const data = await loadPerson(
          session,
          context.params.personId,
          personTab(context.url.searchParams.get('tab')),
        )
        return context.render(
          <PersonShowPage
            {...data}
            tab={personTab(context.url.searchParams.get('tab'))}
            notice={takeWorkflowNotice()}
            orgQuery={orgQuery(context.url)}
            returnTo={listReturn(context.url.searchParams.get('return_to'))}
          />,
        )
      } catch {
        return notFound(context, {
          title: 'Person not found',
          message: 'This person was removed, or you do not have access to their profile.',
          href: routes.peopleIndex.href(),
          linkLabel: 'Back to People',
        })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? 'message')
      let workflowResult: ApplicationActionResult | undefined
      let bookingDraft: BookingDraft | undefined
      let preview: { subject: string; body: string } | undefined
      const applicationId = String(form.get('application_id') ?? '')
      try {
        let notice = 'Saved'
        if (intent === 'erase') {
          if (signedIn()?.roleKey !== 'owner' || !signedIn()?.permissions?.includes('person.erase'))
            throw new Error('Only an owner can erase personal data.')
          await erasePerson(session, context.params.personId)
          return new Response(null, {
            status: 303,
            headers: {
              Location:
                listReturn(context.url.searchParams.get('return_to')) ??
                `${routes.peopleIndex.href()}${orgQuery(context.url)}`,
            },
          })
        }
        if (
          [
            'transition',
            'archive',
            'scorecard',
            'preview_booking',
            'book_panel',
            'scheduling_link',
            'create_offer',
          ].includes(intent)
        ) {
          if (!signedIn()?.permissions?.includes(applicationActionPermission(intent)))
            throw new Error('Application actions are not available.')
          const application = await getApplication(session, applicationId)
          if (application.person_id !== context.params.personId || application.status !== 'active')
            throw new Error('This active application does not belong to this person.')
          workflowResult = await runApplicationAction(session, applicationId, form, (draft) => {
            bookingDraft = draft
          })
          if (!workflowResult.bookingReview && !workflowResult.schedulingToken)
            return redirectWithNotice(
              personWorkspaceHref(
                context.params.personId,
                orgQuery(context.url),
                listReturn(context.url.searchParams.get('return_to')),
                'applications',
              ),
              workflowResult.notice ?? 'Saved',
            )
          notice = workflowResult.notice ?? ''
        } else if (intent === 'edit_details' || intent === 'edit_company') {
          if (
            !signedIn()?.permissions?.some((permission) =>
              ['person.update', 'person.edit_details'].includes(permission),
            )
          )
            throw new Error('Person editing is not available.')
          await updatePerson(
            session,
            context.params.personId,
            intent === 'edit_details'
              ? {
                  display_name: String(form.get('display_name') ?? '').trim(),
                  email: String(form.get('email') ?? '').trim(),
                  phone: String(form.get('phone') ?? '').trim(),
                }
              : {
                  affiliation: {
                    id: String(form.get('affiliation_id') ?? '') || undefined,
                    company_id: String(form.get('company_id') ?? ''),
                    title: String(form.get('title') ?? '').trim(),
                  },
                },
          )
          return redirectWithNotice(
            personWorkspaceHref(
              context.params.personId,
              orgQuery(context.url),
              listReturn(context.url.searchParams.get('return_to')),
              'details',
            ),
            'Person details updated.',
          )
        } else if (intent === 'upload_resume') {
          if (!signedIn()?.permissions?.includes('document.upload'))
            throw new Error('Resume uploads are not available.')
          const file = form.get('resume')
          if (!(file instanceof File) || !file.size) throw new Error('Choose a resume file.')
          if (file.size > 10 * 1024 * 1024) throw new Error('Choose a resume smaller than 10 MB.')
          await replacePersonResume(session, context.params.personId, file)
          return redirectWithNotice(
            personWorkspaceHref(
              context.params.personId,
              orgQuery(context.url),
              listReturn(context.url.searchParams.get('return_to')),
              'resume',
            ),
            'Resume uploaded. It will be available after the security scan.',
          )
        } else if (intent === 'add_to_job') {
          const jobId = String(form.get('job_id') ?? '')
          if (!jobId) throw new Error('Choose a job')
          const created = await createApplication(session, {
            job_id: jobId,
            person_id: context.params.personId,
          })
          return redirectWithNotice(
            `${routes.applicationsShow.index.href({ applicationId: created.id })}${orgQuery(context.url)}`,
            'Added to the job.',
          )
        } else if (intent === 'affiliate') {
          await createAffiliation(session, {
            person_id: context.params.personId,
            company_id: String(form.get('company_id') ?? ''),
            title: String(form.get('title') ?? '').trim() || undefined,
            current: true,
          })
          notice = 'Company linked'
        } else if (intent === 'tag') {
          await tagPerson(session, context.params.personId, String(form.get('tag_name') ?? '').trim())
          notice = 'Tag added'
        } else if (intent === 'untag') {
          await untagPerson(session, context.params.personId, String(form.get('tag_id') ?? ''))
          notice = 'Tag removed'
        } else if (intent === 'add_note') {
          await addPersonNote(
            session,
            context.params.personId,
            String(form.get('body') ?? '').trim(),
            form.get('pinned') === '1',
          )
          notice = 'Note added'
        } else if (intent === 'pin_note') {
          await pinPersonNote(session, String(form.get('note_id') ?? ''), form.get('pinned') === '1')
          notice = form.get('pinned') === '1' ? 'Note pinned' : 'Note unpinned'
        } else if (intent === 'add_task') {
          const dueOn = String(form.get('due_on') ?? '')
          await createFollowUp(session, {
            person_id: context.params.personId,
            title: String(form.get('title') ?? '').trim(),
            task_type: String(form.get('task_type') ?? 'other'),
            // End of the chosen day in the display zone, so "due Friday" is not overdue on Friday morning.
            due_at: dueOn ? new Date(`${dueOn}T17:00:00-05:00`).toISOString() : undefined,
          })
          notice = 'Follow-up added'
        } else if (intent === 'complete_task') {
          await completeFollowUp(session, String(form.get('task_id') ?? ''))
          notice = 'Follow-up done'
        } else if (intent === 'classify_reply') {
          const to = String(form.get('classification') ?? '')
          if (!(REPLY_LABELS as readonly string[]).includes(to)) throw new Error('Choose how they replied')
          await classifyReply(session, String(form.get('communication_id') ?? ''), to)
          notice = `Reply marked: ${label(to)}`
        } else if (intent === 'preview_message') {
          preview = await previewPersonMessage(session, context.params.personId, composeInput(form))
        } else {
          const input = composeInput(form)
          if (!input.template_key && (!input.subject || !input.body))
            throw new Error('Subject and body are required')
          await sendCommunication(session, context.params.personId, input)
          notice = 'Message sent'
        }
        const data = await loadPerson(
          session,
          context.params.personId,
          personTab(context.url.searchParams.get('tab')),
        )
        return context.render(
          <PersonShowPage
            {...data}
            tab={personTab(context.url.searchParams.get('tab'))}
            orgQuery={orgQuery(context.url)}
            returnTo={listReturn(context.url.searchParams.get('return_to'))}
            notice={notice}
            preview={preview}
            draft={preview ? draftOf(form) : undefined}
            workflowResult={workflowResult}
            activeApplicationId={applicationId}
          />,
        )
      } catch (error) {
        try {
          const data = await loadPerson(
            session,
            context.params.personId,
            personTab(context.url.searchParams.get('tab')),
          )
          return context.render(
            <PersonShowPage
              {...data}
              tab={personTab(context.url.searchParams.get('tab'))}
              orgQuery={orgQuery(context.url)}
              returnTo={listReturn(context.url.searchParams.get('return_to'))}
              error={workflowError(error)}
              actionIntent={intent}
              activeApplicationId={applicationId}
              workflowResult={{ bookingDraft }}
              editValues={Object.fromEntries(
                [...form.entries()].filter(
                  (entry): entry is [string, string] => typeof entry[1] === 'string',
                ),
              )}
              toStageKey={String(form.get('to_stage_key') ?? '')}
              archiveReasonKey={String(form.get('archive_reason') ?? '')}
            />,
          )
        } catch {
          return new Response(String(error), { status: 502 })
        }
      }
    },
  },
})
