import type { Handle } from 'remix/component'
import type { Application, Interview, Scorecard, ScorecardRubric } from '../../data/api.ts'
import { interviewLabel } from '../../data/application-workflow.ts'
import { signedIn } from '../../data/auth.ts'
import { applicationHref } from '../../data/hubs.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { Shell } from '../../ui/shell.tsx'
import { InterviewFeedback, interviewTime, type FeedbackViewer } from '../applications/feedback.tsx'

/** One interview on its own page: who, when, the panel, and its feedback. */
export function InterviewDetailPage(
  handle: Handle<{
    interview: Interview
    application: Application
    scorecards: Scorecard[]
    rubrics: ScorecardRubric[]
    hiringTeam: Array<{ userId: string; name: string }>
    orgQuery: string
    notice?: string
  }>,
) {
  return () => {
    const { interview, application, scorecards, rubrics, hiringTeam, orgQuery, notice } = handle.props
    const stages = application.pipeline?.stages ?? []
    const stage = stages.find((row) => row.key === interview.stage_key)
    const name = interviewLabel(interview.interview_key, stages, interview.stage_key)
    const candidate = application.person?.display_name ?? 'Candidate'
    const appHref = applicationHref(application.id, orgQuery)
    const action = `${routes.applicationsShow.action.href({ applicationId: application.id })}${orgQuery}`
    const panel = (interview.interviewer_user_ids ?? []).map(
      (id) =>
        (id === signedIn()?.userId ? 'You' : hiringTeam.find((member) => member.userId === id)?.name) ??
        'Interviewer',
    )
    const viewer: FeedbackViewer = {
      userId: signedIn()?.userId,
      canWrite: Boolean(
        application.status === 'active' && signedIn()?.permissions?.includes('scorecard.write'),
      ),
      demo: Boolean(signedIn()?.demo),
    }
    return (
      <Shell
        title={`${name} · ${candidate}`}
        eyebrow="Interview"
        orgQuery={orgQuery}
        backHref={`${routes.interviewsIndex.href()}${orgQuery}`}
        backLabel="Interviews"
        titleActions={
          <a class="btn btn-ghost" href={appHref}>
            Open application
          </a>
        }
      >
        {notice ? (
          <p class="notice" role="status">
            {notice}
          </p>
        ) : null}
        <section class="record-section" aria-label="Interview details">
          <dl class="field-list">
            <div>
              <dt>Candidate</dt>
              <dd>
                <a href={appHref}>{candidate}</a>
              </dd>
            </div>
            <div>
              <dt>Job</dt>
              <dd>{application.job?.title ?? 'Job'}</dd>
            </div>
            <div>
              <dt>Stage</dt>
              <dd>{stage?.name ?? label(interview.stage_key ?? '')}</dd>
            </div>
            <div>
              <dt>When</dt>
              <dd>{interview.starts_at ? interviewTime(interview.starts_at) : 'Not scheduled'}</dd>
            </div>
            <div>
              <dt>Interviewers</dt>
              <dd>{panel.length ? panel.join(', ') : 'None assigned'}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{label(interview.status)}</dd>
            </div>
          </dl>
        </section>
        <section class="section-card" aria-label="Feedback">
          <h2>Feedback</h2>
          <div class="feedback-list">
            <InterviewFeedback
              interview={interview}
              stages={stages}
              scorecards={scorecards}
              rubrics={rubrics}
              people={hiringTeam}
              viewer={viewer}
              action={action}
              applicationId={application.id}
              returnToInterview
              open
            />
          </div>
        </section>
      </Shell>
    )
  }
}
