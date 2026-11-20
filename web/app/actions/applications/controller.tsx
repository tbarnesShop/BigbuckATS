import { createController } from 'remix/router'

import {
  bookPanel,
  createApplicationTransition,
  createOffer,
  createSchedulingLink,
  createScorecard,
  getApplication,
  getJob,
  listApplicationTransitions,
  listApplications,
  listCommunications,
  listInterviews,
  listScorecardRubrics,
  listScorecards,
  updateScorecard,
  previewPanel,
  sessionFromEnv,
  sessionFromRequest,
  type Communication,
  type Scorecard,
  type ScorecardRubric,
} from '../../data/api.ts'
import { applicationArchiveReason } from '../../data/application-archive.ts'
import { redirectWithNotice, takeWorkflowNotice, signedIn } from '../../data/auth.ts'
import {
  interviewPlan,
  workflowError,
  type BookingDraft,
  type BookingReview,
} from '../../data/application-workflow.ts'
import { loadPersonDocuments } from '../../data/documents.ts'
import { listReturn, recordQuery } from '../../data/record-return.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { ApplicationShowPage } from './pages.tsx'

async function loadPage(
  session: NonNullable<ReturnType<typeof sessionFromRequest>>,
  applicationId: string,
  orgQueryStr: string,
  extras?: {
    error?: string
    notice?: string
    schedulingToken?: string
    toStageKey?: string
    archiveReasonKey?: string
    actionIntent?: string
    bookingDraft?: BookingDraft
    bookingReview?: BookingReview
  },
) {
  const queryParams = new URLSearchParams(orgQueryStr)
  const returnTo = listReturn(queryParams.get('return_to'))
  queryParams.delete('return_to')
  const navigationQuery = queryParams.size ? `?${queryParams}` : ''
  const [application, transitions, interviews] = await Promise.all([
    getApplication(session, applicationId),
    listApplicationTransitions(session, applicationId),
    listInterviews(session, applicationId),
  ])
  const [job, siblings, communications, scorecards, rubrics, documents] = await Promise.all([
    getJob(session, application.job_id).catch(() => null),
    listApplications(session, {
      jobId: application.job_id,
      sort: 'mine',
      perPage: 100,
    }).catch(() => ({ data: [] })),
    application.person_id
      ? listCommunications(session, application.person_id).catch(() => ({
          data: [] as Communication[],
        }))
      : Promise.resolve({ data: [] as Communication[] }),
    listScorecards(session, { applicationId }).catch(() => ({
      data: [] as Scorecard[],
    })),
    listScorecardRubrics(session).catch(() => ({
      data: [] as ScorecardRubric[],
    })),
    loadPersonDocuments(session, application.person_id),
  ])
  const ordered = siblings.data
  const index = ordered.findIndex((row) => row.id === application.id)
  const prev = index > 0 ? ordered[index - 1] : undefined
  const next = index >= 0 && index < ordered.length - 1 ? ordered[index + 1] : undefined
  return (
    <ApplicationShowPage
      application={application}
      documents={documents}
      transitions={transitions.data}
      interviews={interviews.data}
      orgQuery={navigationQuery}
      returnTo={returnTo}
      error={extras?.error}
      notice={extras?.notice}
      schedulingToken={extras?.schedulingToken}
      toStageKey={extras?.toStageKey}
      archiveReasonKey={extras?.archiveReasonKey}
      actionIntent={extras?.actionIntent}
      bookingDraft={extras?.bookingDraft}
      bookingReview={extras?.bookingReview}
      hiringTeam={(job?.hiring_team ?? []).map((member) => ({
        userId: member.user_id,
        name: member.name ?? member.user_id,
        email: member.email ?? '',
      }))}
      previous={prev ? { id: prev.id, name: prev.person?.display_name ?? 'Previous' } : null}
      next={next ? { id: next.id, name: next.person?.display_name ?? 'Next' } : null}
      communications={communications.data}
      scorecards={scorecards.data}
      rubrics={rubrics.data}
    />
  )
}

export type ApplicationActionResult = {
  notice?: string
  schedulingToken?: string
  bookingDraft?: BookingDraft
  bookingReview?: BookingReview
}

export function applicationActionPermission(intent: string) {
  return intent === 'scorecard'
    ? 'scorecard.write'
    : ['preview_booking', 'book_panel', 'scheduling_link'].includes(intent)
      ? 'interview.schedule'
      : intent === 'create_offer'
        ? 'offer.create'
        : 'application.move_stage'
}

export async function runApplicationAction(
  session: NonNullable<ReturnType<typeof sessionFromRequest>>,
  applicationId: string,
  form: FormData,
  setDraft: (draft: BookingDraft) => void = () => {},
): Promise<ApplicationActionResult> {
  const intent = String(form.get('intent') ?? 'transition')
  const permission = applicationActionPermission(intent)
  if (!signedIn()?.permissions?.includes(permission))
    throw new Error('Application actions are not available.')
  let bookingDraft: BookingDraft | undefined
  const complete = (notice: string) => ({ notice })
  if (intent === 'create_offer') {
    const salary = String(form.get('base_salary') ?? '').trim()
    if (!salary || !Number.isFinite(Number(salary)) || Number(salary) <= 0)
      throw new Error('Enter a valid base salary greater than zero.')
    await createOffer(session, applicationId, {
      base_salary: salary ? Number(salary) : 150000,
      currency: 'USD',
    })
    return complete('Draft offer created. Open it below to review and submit for approval.')
  }
  if (intent === 'scheduling_link') {
    const application = await getApplication(session, applicationId)
    const keys = interviewPlan(application).map((row) => row.key)
    if (!keys.length) throw new Error('This stage has no interviews to schedule.')
    const link = await createSchedulingLink(session, applicationId, keys)
    return { notice: 'Scheduling link created', schedulingToken: link.token }
  }
  if (intent === 'book_panel') {
    const token = String(form.get('booking_token') ?? '').trim()
    if (!token) throw new Error('Choose an interview time before booking.')
    await bookPanel(session, applicationId, { booking_token: token })
    return complete('Interview booked at the selected time. Submit feedback after the interview.')
  }
  if (intent === 'preview_booking') {
    const interviewerId = String(form.get('interviewer_user_id') ?? '').trim()
    let interviewerEmail = String(form.get('interviewer_email') ?? '').trim()
    const organizer = String(form.get('organizer_calendar') ?? '').trim()
    const application = await getApplication(session, applicationId)
    const job = await getJob(session, application.job_id)
    if (application.status !== 'active') throw new Error('Only active candidates can be scheduled.')
    if (!job.hiring_team?.some((member) => member.user_id === interviewerId))
      throw new Error('Choose an interviewer from the hiring team.')
    const definition = interviewPlan(application).find((row) => row.key === String(form.get('interview_key')))
    if (!definition) throw new Error('Choose an interview from this stage’s plan.')
    interviewerEmail =
      job.hiring_team?.find((member) => member.user_id === interviewerId)?.email || interviewerEmail
    if (!interviewerEmail || !organizer)
      throw new Error('Enter the interviewer email and organizer calendar.')
    const duration = Number(form.get('duration_minutes') ?? definition.duration_minutes ?? 30)
    if (!Number.isInteger(duration) || duration < 15 || duration > 480)
      throw new Error('Interview duration must be between 15 and 480 minutes.')
    const searchDate = String(form.get('search_date') ?? '').trim()
    bookingDraft = {
      interviewKey: definition.key,
      interviewerId,
      interviewerEmail,
      organizer,
      duration,
      searchDate,
    }
    setDraft(bookingDraft)
    const start = new Date(`${searchDate}T00:00:00.000Z`)
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(searchDate) ||
      !Number.isFinite(start.getTime()) ||
      start.toISOString().slice(0, 10) !== searchDate
    )
      throw new Error('Choose a valid date to start searching.')
    const end = new Date(start)
    end.setUTCDate(end.getUTCDate() + 5)
    const result = await previewPanel(session, applicationId, {
      organizer_calendar: organizer,
      search_start: start.toISOString(),
      search_end: end.toISOString(),
      interview_defs: [
        {
          key: definition.key,
          duration_minutes: duration,
          count: 1,
          candidate_user_ids: [interviewerId],
        },
      ],
      profiles: [{ user_id: interviewerId, paused: false }],
      user_emails: { [interviewerId]: interviewerEmail },
    })
    if (!result.options.length) throw new Error('no_options')
    return {
      bookingDraft,
      bookingReview: {
        draft: bookingDraft,
        interviewName: definition.name ?? definition.key,
        interviewerName:
          job.hiring_team?.find((member) => member.user_id === interviewerId)?.name ?? interviewerEmail,
        options: result.options,
      },
    }
  }
  if (intent === 'scorecard') {
    const interviewId = String(form.get('interview_id') ?? '').trim()
    const interviews = await listInterviews(session, applicationId)
    const interview = interviews.data.find((row) => row.id === interviewId)
    if (!interview) throw new Error('Interview does not belong to this application.')
    const rating = String(form.get('rating') ?? '').trim()
    const notes = String(form.get('notes') ?? '').trim()
    const attributeRatings: Record<string, string> = {}
    for (const [key, value] of form.entries()) {
      if (typeof key === 'string' && key.startsWith('attribute_') && String(value).trim()) {
        attributeRatings[key.slice('attribute_'.length)] = String(value)
      }
    }
    const scorecard = {
      rating,
      ...(notes ? { notes } : {}),
      ...(Object.keys(attributeRatings).length ? { attribute_ratings: attributeRatings } : {}),
    }
    // Who may write or correct feedback is decided by the API (assigned interviewers; the author or
    // scorecard.manage for a correction). Its refusals come back as readable errors.
    const scorecardId = String(form.get('scorecard_id') ?? '').trim()
    if (scorecardId) {
      await updateScorecard(session, scorecardId, scorecard)
      return complete('Feedback updated.')
    }
    await createScorecard(session, { interview_id: interviewId, ...scorecard })
    return complete('Feedback submitted.')
  }
  if (intent === 'archive') {
    if (!signedIn()?.permissions?.includes('application.move_stage'))
      throw new Error('Application actions are not available.')
    const application = await getApplication(session, applicationId)
    if (application.status !== 'active') throw new Error('Only an active application can be archived.')
  }
  const archive =
    intent === 'archive' ? applicationArchiveReason(String(form.get('archive_reason') ?? '')) : undefined
  const command = archive?.command ?? String(form.get('command') ?? 'move')
  const toStageKey = String(form.get('to_stage_key') ?? '').trim()
  const reason = archive?.label ?? String(form.get('reason') ?? '').trim()
  await createApplicationTransition(session, applicationId, {
    command,
    to_stage_key: toStageKey || undefined,
    reason: reason || undefined,
  })
  const fresh = await getApplication(session, applicationId)
  return complete(
    archive
      ? `Application archived: ${archive.label}.`
      : command === 'move'
        ? `Moved to ${fresh.pipeline?.stages.find((row) => row.key === toStageKey)?.name ?? toStageKey}.`
        : command === 'hire'
          ? 'Candidate marked hired.'
          : `${command} recorded`,
  )
}

export default createController(routes.applicationsShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        return context.render(
          await loadPage(session, context.params.applicationId, recordQuery(context.url), {
            notice: takeWorkflowNotice(),
          }),
        )
      } catch {
        return new Response('Application not found', { status: 404 })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? 'transition')
      let bookingDraft: BookingDraft | undefined
      // Feedback filed from an interview's own page goes back to that page.
      const interviewId = String(form.get('interview_id') ?? '')
      const backToInterview = intent === 'scorecard' && form.get('after') === 'interview' && interviewId
      const complete = (notice: string) =>
        redirectWithNotice(
          backToInterview
            ? `${routes.interviewsShow.href({ interviewId })}${orgQuery(context.url)}`
            : `${routes.applicationsShow.index.href({ applicationId: context.params.applicationId })}${recordQuery(context.url)}`,
          notice,
        )
      try {
        const result = await runApplicationAction(session, context.params.applicationId, form, (draft) => {
          bookingDraft = draft
        })
        if (result.bookingReview || result.schedulingToken)
          return context.render(
            await loadPage(session, context.params.applicationId, recordQuery(context.url), result),
          )
        return complete(result.notice ?? 'Saved')
      } catch (error) {
        try {
          return context.render(
            await loadPage(session, context.params.applicationId, recordQuery(context.url), {
              error: workflowError(error),
              actionIntent: intent,
              archiveReasonKey: String(form.get('archive_reason') ?? ''),
              toStageKey: String(form.get('to_stage_key') ?? ''),
              bookingDraft,
            }),
          )
        } catch {
          return new Response(`Action failed: ${String(error)}`, {
            status: 502,
          })
        }
      }
    },
  },
})
