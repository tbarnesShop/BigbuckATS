import type { Handle } from 'remix/component'
import type {
  Application,
  Communication,
  Interview,
  Scorecard,
  ScorecardRubric,
  StageTransition,
} from '../../data/api.ts'
import {
  interviewLabel,
  interviewPlan,
  pendingFeedback,
  type BookingDraft,
  type BookingReview,
} from '../../data/application-workflow.ts'
import { InterviewFeedback, interviewTime, type FeedbackViewer } from './feedback.tsx'
import { jobWorkspaceHref, sectionForStage, stageLabel } from '../../data/board.ts'
import { signedIn } from '../../data/auth.ts'
import { recordHref, returnLabel } from '../../data/record-return.ts'
import { personWorkspaceHref } from '../../data/person-workspace.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { ApplicationActions } from '../../ui/application-actions.tsx'
import { ResumeSection } from '../../ui/resume.tsx'
import type { PersonDocuments } from '../../data/documents.ts'
import { Field, Mute, Shell } from '../../ui/shell.tsx'

export function ApplicationShowPage(
  handle: Handle<{
    application: Application
    embedded?: boolean
    actionHref?: string
    transitions: StageTransition[]
    interviews: Interview[]
    orgQuery: string
    returnTo?: string
    documents?: PersonDocuments
    error?: string
    notice?: string
    schedulingToken?: string
    toStageKey?: string
    archiveReasonKey?: string
    actionIntent?: string
    bookingDraft?: BookingDraft
    bookingReview?: BookingReview
    hiringTeam?: Array<{ userId: string; name: string; email?: string }>
    previous?: { id: string; name: string } | null
    next?: { id: string; name: string } | null
    communications?: Communication[]
    scorecards?: Scorecard[]
    rubrics?: ScorecardRubric[]
  }>,
) {
  return () => {
    const {
      application,
      transitions,
      interviews,
      orgQuery,
      returnTo,
      error,
      notice,
      schedulingToken,
      hiringTeam = [],
      previous,
      next,
      communications = [],
      scorecards = [],
      rubrics = [],
      bookingDraft,
      bookingReview,
    } = handle.props
    const stages = application.pipeline?.stages ?? []
    const currentIndex = stages.findIndex((stage) => stage.key === application.current_stage_key)
    const current = stages[currentIndex]
    const plan = interviewPlan(application)
    const missing = pendingFeedback(application, interviews, scorecards)
    const active = application.status === 'active'
    const canMove = active && signedIn()?.permissions?.includes('application.move_stage')
    const canSchedule = active && signedIn()?.permissions?.includes('interview.schedule')
    const viewer: FeedbackViewer = {
      userId: signedIn()?.userId,
      canWrite: Boolean(active && signedIn()?.permissions?.includes('scorecard.write')),
      demo: Boolean(signedIn()?.demo),
    }
    const action =
      handle.props.actionHref ??
      recordHref(routes.applicationsShow.action.href({ applicationId: application.id }), orgQuery, returnTo)
    const cancelBookingHref = `${action}${action.includes('?') ? '&' : '?'}booking=cancelled${handle.props.embedded ? '' : '#interview-plan'}`
    const boardHref = jobWorkspaceHref(application.job_id, orgQuery, {
      section: active ? sectionForStage(current ?? { key: application.current_stage_key ?? '' }) : 'closed',
    })
    const available = plan.filter(
      (row) =>
        !interviews.some(
          (interview) =>
            interview.stage_key === application.current_stage_key &&
            interview.interview_key === row.key &&
            interview.status !== 'cancelled',
        ),
    )
    const offerStage = current?.type === 'offer' || current?.key === 'offer'
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
    const embedded = handle.props.embedded
    const hasHiredStage = stages.some((stage) => stage.type === 'hired')
    const interviewerNames = (interview: Interview) =>
      (interview.interviewer_user_ids ?? [])
        .map((id) => hiringTeam.find((member) => member.userId === id)?.name)
        .filter(Boolean)
        .join(', ')
    const feedbackProps = {
      stages,
      scorecards,
      rubrics,
      people: hiringTeam,
      viewer,
      action,
      applicationId: application.id,
    }
    // Everything not shown under the current stage's plan: earlier stages, cancelled and repeat bookings.
    const inPlan = new Set(
      plan
        .map(
          (definition) =>
            interviews.find(
              (interview) =>
                interview.stage_key === current?.key &&
                interview.interview_key === definition.key &&
                interview.status !== 'cancelled',
            )?.id,
        )
        .filter(Boolean),
    )
    const earlier = interviews.filter((interview) => !inPlan.has(interview.id))
    const upcoming = interviews
      .filter(
        (interview) =>
          interview.status === 'scheduled' &&
          interview.starts_at &&
          new Date(interview.starts_at).getTime() > Date.now() - 60 * 60 * 1000,
      )
      .sort((a, b) => String(a.starts_at).localeCompare(String(b.starts_at)))
    const content = (
      <div class="record-workspace">
        {!embedded ? (
          <>
            {returnTo ? (
              <p class="record-context">
                <a href={boardHref}>Open job pipeline</a>
              </p>
            ) : null}
            {application.person?.primary_email ? <p class="sub">{application.person.primary_email}</p> : null}
            <div class="step-track" role="list" aria-label="Candidate pipeline">
              {stages.map((stage, index) => (
                <span
                  key={stage.key}
                  class="step"
                  role="listitem"
                  aria-current={
                    (active || application.status === 'hired') && stage.key === application.current_stage_key
                      ? 'step'
                      : undefined
                  }
                >
                  {index + 1}. {stageLabel(stage, stage.key)}
                </span>
              ))}
              {hasHiredStage ? null : (
                <span
                  class="step"
                  role="listitem"
                  aria-current={application.status === 'hired' ? 'step' : undefined}
                >
                  Hired
                </span>
              )}
            </div>
            {upcoming.length ? (
              <p class="schedule-banner" role="status">
                <span class="chip chip-ok">Scheduled</span>{' '}
                {upcoming
                  .slice(0, 3)
                  .map(
                    (interview) =>
                      `${interviewLabel(interview.interview_key, stages, interview.stage_key)} · ${interviewTime(interview.starts_at ?? '')}${interviewerNames(interview) ? ` with ${interviewerNames(interview)}` : ''}`,
                  )
                  .join('; ')}
                {upcoming.length > 3 ? ` and ${upcoming.length - 3} more` : ''}.{' '}
                <a href={embedded ? `#interview-plan-${application.id}` : '#interview-plan'}>
                  Interview plan
                </a>
              </p>
            ) : active &&
              plan.length &&
              !interviews.some(
                (row) => row.stage_key === application.current_stage_key && row.status !== 'cancelled',
              ) ? (
              <p class="sub">No interviews scheduled for this stage yet.</p>
            ) : null}
            {notice ? (
              <p class="notice" role="status">
                {notice}
              </p>
            ) : null}
            {error ? (
              <p class="notice-bad" role="alert">
                {error}
              </p>
            ) : null}
            <ResumeSection
              personId={application.person_id}
              documents={handle.props.documents}
              orgQuery={orgQuery}
            />
          </>
        ) : null}
        {application.application_form_snapshot?.length ? (
          <details class="record-section" aria-label="Application responses">
            <summary>Application responses</summary>
            <p class="sub">
              Submitted through posting {application.posting_id}. Questions are shown as they were at
              submission.
            </p>
            <dl>
              {application.application_form_snapshot.map((question) => (
                <div key={question.key}>
                  <dt>{question.label}</dt>
                  <dd>
                    {Array.isArray(application.application_answers?.[question.key])
                      ? ((application.application_answers?.[question.key] ?? []) as unknown[]).join(', ')
                      : String(application.application_answers?.[question.key] ?? 'Not answered')}
                  </dd>
                </div>
              ))}
            </dl>
          </details>
        ) : null}
        <div class="stack application-sections">
          {!canMove ? (
            <p class="notice">
              {active
                ? 'Stage changes are managed by your recruiting team.'
                : `This application is ${label(application.status).toLowerCase()}.`}
            </p>
          ) : null}

          {offerStage || application.offers?.length ? (
            <section class="section-card" aria-label="Offers">
              <h2>Offers</h2>
              {(() => {
                const offers = application.offers ?? []
                const accepted = offers.some((offer) => offer.status === 'accepted')
                const sent = offers.find((offer) => offer.status === 'sent')
                const canHire = signedIn()?.permissions?.includes('application.move_stage') ?? false
                if (active && accepted && canHire) {
                  return (
                    <div class="candidate-next-step">
                      <strong>Next step: mark hired</strong>
                      <p>The offer is accepted. Marking hired moves the candidate into the Hired stage.</p>
                      <form method="post" action={action} data-application-id={application.id}>
                        <input type="hidden" name="intent" value="transition" />
                        <input type="hidden" name="command" value="hire" />
                        <button class="btn btn-primary" type="submit">
                          Mark hired
                        </button>
                      </form>
                    </div>
                  )
                }
                if (active && sent) {
                  return (
                    <div class="candidate-next-step">
                      <strong>Waiting for the candidate</strong>
                      <p>
                        The offer letter is sent. They answer through the link in it, or{' '}
                        <a href={`${routes.offersShow.index.href({ offerId: sent.id })}${orgQuery}`}>
                          record their answer on the offer
                        </a>
                        .
                      </p>
                    </div>
                  )
                }
                return null
              })()}
              {application.offers?.length ? (
                <ul class="queue">
                  {application.offers.map((offer) => (
                    <li key={offer.id} class="queue-item">
                      <a href={`${routes.offersShow.index.href({ offerId: offer.id })}${orgQuery}`}>
                        Open offer · {label(offer.status)}
                      </a>
                    </li>
                  ))}
                </ul>
              ) : active && signedIn()?.permissions?.includes('offer.create') ? (
                <form method="post" action={action} class="form-narrow">
                  <input type="hidden" name="application_id" value={application.id} />
                  <input type="hidden" name="intent" value="create_offer" />
                  <label class="field">
                    <span>Base salary (USD)</span>
                    <input name="base_salary" type="number" min="1" step="1" required />
                  </label>
                  <button class="btn btn-primary" type="submit">
                    Create draft offer
                  </button>
                </form>
              ) : (
                <Mute>No offers.</Mute>
              )}
            </section>
          ) : null}
          {/* Always rendered: other pages link to #interview-plan, and an empty stage says so. */}
          {application ? (
            <section
              class="section-card"
              id={embedded ? `interview-plan-${application.id}` : 'interview-plan'}
              aria-label="Interview plan"
            >
              <h2>Interview plan</h2>
              {plan.length ? (
                <div class="feedback-list">
                  {plan.map((definition) => {
                    const booked = interviews.find(
                      (interview) =>
                        interview.stage_key === current?.key &&
                        interview.interview_key === definition.key &&
                        interview.status !== 'cancelled',
                    )
                    return booked ? (
                      <InterviewFeedback key={definition.key} interview={booked} {...feedbackProps} />
                    ) : (
                      <div key={definition.key} class="feedback-interview feedback-unbooked">
                        <span class="feedback-title">{definition.name ?? definition.key}</span>
                        <span class="chip">Not scheduled</span>
                        <span class="feedback-when">
                          {definition.required === false ? 'Optional' : 'Required'}
                        </span>
                      </div>
                    )
                  })}
                </div>
              ) : (
                <p class="sub">
                  {current?.name ?? 'This stage'} has no interviews.{' '}
                  {application.job_id ? (
                    <a
                      href={`${jobWorkspaceHref(application.job_id, orgQuery, { tab: 'settings' })}#interview-plan`}
                    >
                      Add interviews to this stage
                    </a>
                  ) : null}
                </p>
              )}
              {canSchedule && available.length ? (
                <>
                  {bookingReview ? (
                    <section class="section-card" aria-label="Review interview times">
                      <h3>Review interview times</h3>
                      <p>
                        {bookingReview.interviewName} · {bookingReview.draft.duration} minutes
                      </p>
                      <p class="sub">
                        Candidate: {application.person?.display_name ?? 'Candidate'}
                        <br />
                        Interviewer: {bookingReview.interviewerName} ({bookingReview.draft.interviewerEmail}
                        )
                        <br />
                        Organizer: {bookingReview.draft.organizer}
                      </p>
                      <form method="post" action={action}>
                        <input type="hidden" name="application_id" value={application.id} />
                        <input type="hidden" name="intent" value="book_panel" />
                        <fieldset>
                          <legend>Choose a time (Eastern time)</legend>
                          {bookingReview.options.map((option, index) => (
                            <label key={option.token} class="field">
                              <span>
                                <input
                                  type="radio"
                                  name="booking_token"
                                  value={option.token}
                                  checked={index === 0}
                                  required
                                />{' '}
                                {interviewTime(option.starts_at)} – {interviewTime(option.ends_at)}
                              </span>
                            </label>
                          ))}
                        </fieldset>
                        <p class="sub">
                          Nothing is booked yet. Availability will be checked again when you confirm. These
                          options expire in 10 minutes.
                        </p>
                        <button class="btn btn-primary" type="submit">
                          Confirm interview booking
                        </button>{' '}
                        <a href={cancelBookingHref}>Cancel</a>
                      </form>
                    </section>
                  ) : null}
                  <details open={!embedded || Boolean(bookingDraft || bookingReview)}>
                    <summary>{bookingReview ? 'Change search' : 'Schedule an interview'}</summary>
                    <form method="post" action={action} class="form-narrow">
                      <input type="hidden" name="application_id" value={application.id} />
                      <input type="hidden" name="intent" value="preview_booking" />
                      <label class="field">
                        <span>Interview</span>
                        <select name="interview_key" aria-label="Interview" required>
                          {available.map((definition) => (
                            <option
                              key={definition.key}
                              value={definition.key}
                              selected={definition.key === bookingDraft?.interviewKey}
                            >
                              {definition.name ?? definition.key}
                            </option>
                          ))}
                        </select>
                      </label>
                      <label class="field">
                        <span>Interviewer</span>
                        <select name="interviewer_user_id" aria-label="Interviewer" required>
                          <option value="">Choose an interviewer</option>
                          {hiringTeam.map((member) => (
                            <option
                              key={member.userId}
                              value={member.userId}
                              selected={
                                bookingDraft
                                  ? member.userId === bookingDraft.interviewerId
                                  : member.name === signedIn()?.name
                              }
                            >
                              {member.name}
                            </option>
                          ))}
                        </select>
                      </label>
                      {!hiringTeam.length ? (
                        <p class="sub">Add a hiring team on the job before scheduling.</p>
                      ) : null}
                      {hiringTeam.some((member) => !member.email) ? (
                        <Field
                          label="Interviewer email"
                          name="interviewer_email"
                          id={`interviewer-email-${application.id}`}
                          email
                          required
                          defaultValue={bookingDraft?.interviewerEmail ?? signedIn()?.email}
                        />
                      ) : null}
                      <label class="field">
                        <span>Duration (minutes)</span>
                        <input
                          type="number"
                          name="duration_minutes"
                          min="15"
                          max="480"
                          defaultValue={String(
                            bookingDraft?.duration ?? available[0]?.duration_minutes ?? 30,
                          )}
                          required
                        />
                      </label>
                      <Field
                        label="Organizer calendar"
                        name="organizer_calendar"
                        id={`organizer-calendar-${application.id}`}
                        required
                        defaultValue={bookingDraft?.organizer ?? 'recruiting@bigbuck.test'}
                      />
                      <label class="field">
                        <span>Search from date</span>
                        <input
                          type="date"
                          name="search_date"
                          required
                          defaultValue={bookingDraft?.searchDate ?? tomorrow}
                        />
                      </label>
                      <p class="sub">
                        Find available times over the following five days. In the demo, calendar invitations
                        stay local.
                      </p>
                      <button class="btn btn-primary" type="submit">
                        Find interview times
                      </button>
                    </form>
                  </details>
                </>
              ) : null}
              {earlier.length ? (
                <>
                  <h3 class="feedback-heading">Earlier interviews</h3>
                  <div class="feedback-list">
                    {earlier.map((interview) => (
                      <InterviewFeedback key={interview.id} interview={interview} {...feedbackProps} />
                    ))}
                  </div>
                </>
              ) : null}
              {canSchedule && plan.length ? (
                <details class="plan-extra">
                  <summary>Candidate self-scheduling</summary>
                  <form method="post" action={action}>
                    <input type="hidden" name="application_id" value={application.id} />
                    <input type="hidden" name="intent" value="scheduling_link" />
                    <button class="btn btn-ghost" type="submit">
                      Create self-schedule link
                    </button>
                  </form>
                </details>
              ) : null}
              {schedulingToken ? (
                <p>
                  Candidate link:{' '}
                  <a
                    href={routes.schedulingPublic.href({
                      token: schedulingToken,
                    })}
                  >
                    Open scheduling page
                  </a>
                </p>
              ) : null}
            </section>
          ) : null}

          <details class="section-card">
            <summary>Conversation</summary>
            {communications.length ? (
              <ul class="queue">
                {communications.map((message) => (
                  <li key={message.id} class="queue-item">
                    <div class="body">
                      <span class="title">{message.subject || message.message_type || 'Message'}</span>
                      <span class="hint">
                        {label(message.direction)} · {label(message.status)}
                        {message.body ? ` · ${message.body}` : ''}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            ) : (
              <Mute>No messages yet.</Mute>
            )}
            <a href={personWorkspaceHref(application.person_id, orgQuery, returnTo, 'activity')}>
              Open person to send a message
            </a>
          </details>
          <details class="section-card" open={!embedded}>
            <summary>Stage history</summary>
            {transitions.length ? (
              <ol>
                {transitions.map((transition) => (
                  <li key={transition.id}>
                    {transition.command === 'move'
                      ? `${stageLabel(
                          stages.find((row) => row.key === transition.from_stage_key),
                          transition.from_stage_key ?? 'Start',
                        )} → ${stageLabel(
                          stages.find((row) => row.key === transition.to_stage_key),
                          transition.to_stage_key,
                        )}`
                      : transition.command === 'hire'
                        ? `${stageLabel(
                            stages.find((row) => row.key === transition.from_stage_key),
                            transition.from_stage_key ?? 'Offer',
                          )} → Hired`
                        : label(transition.command)}
                    {transition.reason ? ` · ${transition.reason}` : ''}
                  </li>
                ))}
              </ol>
            ) : (
              <Mute>No stage changes yet.</Mute>
            )}
          </details>
        </div>
        {!embedded ? (
          <nav class="list-pagination" aria-label="Review">
            {previous ? (
              <a
                class="page-link"
                href={recordHref(
                  routes.applicationsShow.index.href({ applicationId: previous.id }),
                  orgQuery,
                  returnTo,
                )}
              >
                Previous · {previous.name}
              </a>
            ) : (
              <span class="page-link" aria-disabled="true">
                Previous
              </span>
            )}
            {next ? (
              <a
                class="page-link"
                href={recordHref(
                  routes.applicationsShow.index.href({ applicationId: next.id }),
                  orgQuery,
                  returnTo,
                )}
              >
                Next · {next.name}
              </a>
            ) : (
              <span class="page-link" aria-disabled="true">
                Next
              </span>
            )}
          </nav>
        ) : null}
      </div>
    )
    if (embedded) return content
    return (
      <Shell
        title={application.person?.display_name ?? 'Candidate'}
        titleActions={
          <ApplicationActions
            applications={[application]}
            actionFor={() => action}
            allowHire
            error={Boolean(error) && handle.props.actionIntent === 'transition'}
            archiveError={Boolean(error) && handle.props.actionIntent === 'archive'}
            archiveReasonKey={handle.props.archiveReasonKey}
            toStageKey={handle.props.toStageKey}
            guidance={
              missing.length
                ? `Feedback is still missing for ${missing.map((key) => interviewLabel(key, stages, current?.key)).join(', ')}. You can move them on anyway.`
                : undefined
            }
          />
        }
        eyebrow="Candidate application"
        sub={`${application.job?.title ?? 'Job'} · ${stageLabel(current, application.current_stage_key ?? 'No stage')} · ${label(application.status)}`}
        orgQuery={orgQuery}
        backHref={returnTo ?? boardHref}
        backLabel={returnTo ? returnLabel(returnTo) : 'Job pipeline'}
      >
        {content}
      </Shell>
    )
  }
}
