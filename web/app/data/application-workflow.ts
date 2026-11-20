import type { Application, BookingOption, Interview, PipelineStage, Scorecard } from './api.ts'

export type BookingDraft = {
  interviewKey: string
  interviewerId: string
  interviewerEmail: string
  organizer: string
  duration: number
  searchDate: string
}

export type BookingReview = {
  draft: BookingDraft
  interviewName: string
  interviewerName: string
  options: BookingOption[]
}

export function interviewPlan(application: Application) {
  return (
    application.pipeline?.stages.find((stage) => stage.key === application.current_stage_key)?.interviews ??
    []
  )
}

/** A stored key as words, for the rare case a name is missing: "system-design" → "System design". */
export function humanizeKey(key: string) {
  const words = key.replace(/[-_]+/g, ' ').trim()
  return words.charAt(0).toUpperCase() + words.slice(1)
}

export function interviewLabel(key: string, stages: PipelineStage[] = [], stageKey?: string) {
  const stage = stages.find((row) => row.key === stageKey)
  const named =
    stage?.interviews?.find((row) => row.key === key)?.name ||
    stages.flatMap((row) => row.interviews ?? []).find((row) => row.key === key)?.name
  return named || humanizeKey(key)
}

/** An interview has feedback once any interviewer has submitted. Uses the roster the API sends to
 * everyone, so it stays right for people who cannot read the scorecards themselves. */
export function feedbackSubmitted(interview: Interview, scorecards: Scorecard[] = []) {
  return (
    (interview.feedback_submitted_user_ids?.length ?? 0) > 0 ||
    scorecards.some((card) => card.interview_id === interview.id && card.status === 'submitted')
  )
}

export function pendingFeedback(application: Application, interviews: Interview[], scorecards: Scorecard[]) {
  const stage = application.pipeline?.stages.find((row) => row.key === application.current_stage_key)
  const plan = stage?.interviews ?? []
  const requirements = stage?.exit?.require ?? stage?.exit_requirements ?? []
  const mode = requirements.find((row) => row.scorecards_submitted)?.scorecards_submitted?.interviews
  const keys = Array.isArray(mode)
    ? mode
    : plan.filter((row) => mode === 'all' || row.required !== false).map((row) => row.key)
  return keys.filter(
    (key) =>
      !interviews.some(
        (interview) =>
          interview.stage_key === application.current_stage_key &&
          interview.interview_key === key &&
          feedbackSubmitted(interview, scorecards),
      ),
  )
}

export function workflowError(error: unknown, stages: PipelineStage[] = []) {
  const message = error instanceof Error ? error.message : String(error)
  if (message.includes('scorecards_submitted:')) {
    const keys = message
      .split('scorecards_submitted:')[1]
      .split(',')
      .map((key) => interviewLabel(key.trim(), stages))
    return `Submit feedback for ${keys.join(', ')} before moving this candidate. See the interview plan below.`
  }
  if (message.includes('no_approver_block'))
    return 'No one can approve this offer yet. Add a hiring manager to the job’s hiring team, then submit it again.'
  if (message.includes('feedback_before_interview'))
    return 'Feedback opens once the interview has started. Come back after it begins.'
  if (message.includes('interview_unassigned'))
    return 'No interviewers are assigned to this interview yet, so it cannot take feedback.'
  if (message.includes('interview_not_scheduled'))
    return 'This interview has not been scheduled yet. Feedback opens once it starts.'
  if (message.includes('not_an_interviewer'))
    return 'Only the interviewers assigned to this interview can submit feedback.'
  if (message.includes('invalid_rating')) return 'Choose an overall recommendation.'
  if (message.includes('rubric_incomplete:'))
    return 'Complete each required rating before submitting feedback.'
  if (message.includes('calendar_not_connected'))
    return 'Connect an organizer calendar in Settings before booking interviews.'
  if (message.includes('slot_unavailable'))
    return 'That time is no longer available. Find times again and review a new option before booking.'
  if (message.includes('proposal_expired'))
    return 'These interview times have expired. Find times again before booking.'
  if (message.includes('application_changed') || message.includes('application_not_active'))
    return 'The candidate’s stage or status changed. Review their current interview plan before scheduling.'
  if (message.includes('no_options'))
    return 'No available times were found. Try a later date or another interviewer.'
  if (message.includes('hire_requires_accepted_offer'))
    return 'An accepted offer is required before marking this candidate hired.'
  if (message.includes('use_hire_for_hired_stage'))
    return 'Use “Mark hired” to move a candidate into Hired. It checks the offer first.'
  if (message.includes('stage_has_candidates'))
    return 'Move the candidates out of this stage before removing it.'
  if (message.includes('hired_stage_is_fixed')) return 'Hired is always the last stage and cannot be changed.'
  if (message.includes('cannot_move_stage')) return 'That stage is already at the end of the pipeline.'
  if (message.includes('last_stage')) return 'A pipeline needs at least one stage before Hired.'
  if (message.includes('shared_pipeline'))
    return 'This pipeline is shared with another job or pool. Change it in Admin instead.'
  if (message.includes('stale_version')) return 'Someone else saved this first. Reload and try again.'
  if (message.includes('mailbox_not_connected'))
    return 'That mailbox is paused or disconnected. Resume it in Settings → Mailboxes, or send from another one.'
  if (message.includes('override_requires_owner'))
    return 'Only an organization owner can approve on someone else’s behalf.'
  return message
}
