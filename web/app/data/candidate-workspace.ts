import {
  getApplication,
  getJob,
  listApplicationTransitions,
  listInterviews,
  listScorecards,
  listScorecardRubrics,
  type ApiHeaders,
} from './api.ts'
import { interviewPlan, pendingFeedback } from './application-workflow.ts'

export async function loadCandidateWorkspace(session: ApiHeaders, applicationId: string) {
  const [application, transitions, interviews, scorecards, rubrics] = await Promise.all([
    getApplication(session, applicationId),
    listApplicationTransitions(session, applicationId),
    listInterviews(session, applicationId),
    listScorecards(session, { applicationId }),
    listScorecardRubrics(session),
  ])
  const job = await getJob(session, application.job_id)
  return {
    application,
    transitions: transitions.data,
    interviews: interviews.data,
    scorecards: scorecards.data,
    rubrics: rubrics.data,
    hiringTeam: (job.hiring_team ?? []).map((member) => ({
      userId: member.user_id,
      name: member.name ?? member.user_id,
      email: member.email ?? '',
    })),
  }
}
export type CandidateWorkspace = Awaited<ReturnType<typeof loadCandidateWorkspace>>
export type CandidateWorkspaceState = { status: 'ready'; data: CandidateWorkspace } | { status: 'failed' }

export function candidateNextStep(work: CandidateWorkspace) {
  const { application, interviews, scorecards } = work
  if (application.status !== 'active') return `Application ${application.status}.`
  const plan = interviewPlan(application)
  const unscheduled = plan.filter(
    (def) =>
      !interviews.some(
        (row) =>
          row.stage_key === application.current_stage_key &&
          row.interview_key === def.key &&
          row.status !== 'cancelled',
      ),
  )
  if (unscheduled.length) return `Schedule ${unscheduled.map((row) => row.name ?? row.key).join(', ')}.`
  const pending = pendingFeedback(application, interviews, scorecards)
  const upcoming = interviews.filter(
    (row) =>
      row.stage_key === application.current_stage_key &&
      row.status === 'scheduled' &&
      (!row.starts_at || new Date(row.starts_at) > new Date()),
  )
  if (upcoming.length) return 'Upcoming interviews. Review the schedule below.'
  if (pending.length)
    return `Collect feedback for ${pending.map((key) => plan.find((row) => row.key === key)?.name ?? key).join(', ')}.`
  const stages = application.pipeline?.stages ?? []
  const index = stages.findIndex((row) => row.key === application.current_stage_key)
  const stage = stages[index]
  if (stage?.type === 'offer' || stage?.key === 'offer')
    return 'Review the offer and acceptance before marking hired.'
  return stages[index + 1]
    ? `Review the candidate for ${stages[index + 1].name ?? stages[index + 1].key}.`
    : 'Review the final hiring outcome.'
}
