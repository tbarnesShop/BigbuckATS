import type { Handle } from 'remix/component'
import type { Interview, PipelineStage, Scorecard, ScorecardRubric } from '../../data/api.ts'
import { interviewLabel } from '../../data/application-workflow.ts'
import { label } from '../../data/labels.ts'

const RATINGS = ['strong_yes', 'yes', 'mixed', 'no'] as const

/** Who is looking, and what their role lets them do with feedback. */
export type FeedbackViewer = {
  userId?: string
  /** scorecard.write on an active application. Still only for interviews they are assigned to. */
  canWrite: boolean
  demo: boolean
}

type Person = { userId: string; name: string }

function ratingTone(rating?: string | null) {
  if (rating === 'strong_yes' || rating === 'yes') return 'chip chip-ok'
  if (rating === 'mixed') return 'chip chip-warn'
  if (rating === 'no' || rating === 'strong_no') return 'chip chip-bad'
  return 'chip'
}

// Rubric attributes are scored 1 to 5. Scorecards written before that used the overall-rating words.
const SCORES = [
  ['5', '5 · Excellent'],
  ['4', '4 · Strong'],
  ['3', '3 · Mixed'],
  ['2', '2 · Weak'],
  ['1', '1 · Poor'],
] as const
const WORD_SCORES: Record<string, string> = { strong_yes: '5', yes: '4', mixed: '3', no: '2', strong_no: '1' }

function attributeScore(value: string | number | null | undefined) {
  if (value === undefined || value === null || value === '') return ''
  return WORD_SCORES[String(value)] ?? String(value)
}

function attributeValue(value: string | number) {
  const score = attributeScore(value)
  return /^\d+$/.test(score) ? `${score} / 5` : label(score)
}

function attributeName(rubric: ScorecardRubric | undefined, key: string) {
  const attribute = rubric?.attributes_spec?.find((row) => row.key === key)
  return attribute?.label ?? attribute?.name ?? label(key)
}

function firstName(name: string) {
  return name.trim().split(/\s+/)[0] ?? name
}

export function interviewTime(time: string) {
  return new Date(time).toLocaleString('en-US', {
    timeZone: 'America/New_York',
    timeZoneName: 'short',
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

/** Feedback filed before the interview's start time (demo sandboxes allow it; live workspaces refuse it). */
export function submittedEarly(interview: Interview, card: Scorecard) {
  return Boolean(
    interview.starts_at && card.updated_at && Date.parse(card.updated_at) < Date.parse(interview.starts_at),
  )
}

/** Where one interview stands on feedback, from the roster every viewer gets. */
export function feedbackState(interview: Interview, scorecards: Scorecard[], viewer: FeedbackViewer) {
  const panel = interview.interviewer_user_ids ?? []
  const visible = scorecards.filter(
    (card) => card.interview_id === interview.id && card.status === 'submitted',
  )
  const submittedIds = interview.feedback_submitted_user_ids ?? visible.map((card) => card.user_id)
  const startsAt = interview.starts_at ? Date.parse(interview.starts_at) : Number.NaN
  const cancelled = interview.status === 'cancelled'
  const scheduled = interview.status !== 'requested' && !Number.isNaN(startsAt)
  const started = interview.status === 'completed' || (scheduled && startsAt <= Date.now())
  const onPanel = Boolean(viewer.userId && panel.includes(viewer.userId))
  const mine = Boolean(viewer.userId && submittedIds.includes(viewer.userId))
  // Demo sandboxes take feedback on a booked interview before it starts, so a visitor can finish a hire.
  const early = viewer.demo && scheduled && !started
  const owed = viewer.canWrite && onPanel && !mine && !cancelled && (started || early)
  return { panel, visible, submittedIds, cancelled, scheduled, started, onPanel, mine, early, owed }
}

function statusChip(state: ReturnType<typeof feedbackState>) {
  const { panel, submittedIds } = state
  if (state.cancelled) return { tone: 'chip', text: 'Cancelled' }
  if (state.owed && state.started) return { tone: 'chip chip-info', text: 'Your feedback is due' }
  if (!panel.length) return { tone: 'chip chip-warn', text: 'No interviewers assigned' }
  if (!state.scheduled && !state.started) return { tone: 'chip', text: 'Not scheduled' }
  if (!state.started && !submittedIds.length) return { tone: 'chip', text: 'Scheduled' }
  const done = panel.filter((id) => submittedIds.includes(id)).length
  return done >= panel.length
    ? { tone: 'chip chip-ok', text: panel.length === 1 ? 'Feedback in' : `All ${panel.length} feedback in` }
    : { tone: 'chip chip-warn', text: `${done} of ${panel.length} feedback in` }
}

/** One booked interview: who owes feedback, the scorecards this viewer may read, and their own form. */
export function InterviewFeedback(
  handle: Handle<{
    interview: Interview
    stages: PipelineStage[]
    scorecards: Scorecard[]
    rubrics: ScorecardRubric[]
    people: Person[]
    viewer: FeedbackViewer
    action: string
    applicationId: string
    open?: boolean
    /** Posting from the interview's own page: land back there after submitting. */
    returnToInterview?: boolean
  }>,
) {
  return () => {
    const { interview, stages, scorecards, rubrics, people, viewer, action, applicationId } = handle.props
    const name = interviewLabel(interview.interview_key, stages, interview.stage_key)
    const definition = stages
      .find((stage) => stage.key === interview.stage_key)
      ?.interviews?.find((row) => row.key === interview.interview_key)
    const rubric = rubrics.find((row) => row.key === definition?.rubric_key)
    const state = feedbackState(interview, scorecards, viewer)
    const chip = statusChip(state)
    const nameOf = (userId: string) =>
      userId === viewer.userId
        ? 'You'
        : (people.find((person) => person.userId === userId)?.name ??
          state.visible.find((card) => card.user_id === userId)?.user?.name ??
          'Interviewer')
    const hidden = state.submittedIds.filter(
      (id) => !state.visible.some((card) => card.user_id === id),
    ).length
    // People on the panel whose feedback is not in yet. Submitted scorecards speak for themselves below.
    const awaiting = state.panel.filter((id) => !state.submittedIds.includes(id))
    const formProps = {
      action,
      applicationId,
      interviewId: interview.id,
      rubric,
      returnToInterview: handle.props.returnToInterview,
    }
    return (
      <details
        class="feedback-interview"
        id={`interview-${interview.id}`}
        aria-label={`${name} feedback`}
        open={handle.props.open ?? state.owed}
      >
        <summary>
          <span class="feedback-title">{name}</span>
          <span class={chip.tone}>{chip.text}</span>
          {state.visible.some((card) => submittedEarly(interview, card)) ? (
            <span class="chip chip-warn">Submitted before the interview</span>
          ) : null}
          {state.visible.length ? (
            <span class="feedback-verdicts">
              {state.visible.map((card) => (
                <span key={card.id}>
                  {card.user_id === viewer.userId
                    ? 'You'
                    : firstName(card.user?.name ?? nameOf(card.user_id))}{' '}
                  <strong>{label(card.rating ?? '')}</strong>
                </span>
              ))}
            </span>
          ) : null}
          {interview.starts_at ? (
            <span class="feedback-when">{interviewTime(interview.starts_at)}</span>
          ) : null}
        </summary>
        {state.panel.length === 0 ? (
          <p class="sub">
            No interviewers are assigned, so this interview cannot take feedback yet. Book it with an
            interviewer to open it.
          </p>
        ) : awaiting.length ? (
          <p class="panel-roster">
            <span class="panel-roster-label">{state.started ? 'Waiting on' : 'Interviewers'}</span>{' '}
            {awaiting.map(nameOf).join(', ')}
          </p>
        ) : null}
        {state.visible.map((card) => {
          const own = card.user_id === viewer.userId
          const author = card.user?.name ?? nameOf(card.user_id)
          const early = submittedEarly(interview, card)
          return (
            <article key={card.id} class="scorecard" aria-label={`Feedback from ${author}`}>
              <header>
                <strong>{own ? `${author} (you)` : author}</strong>
                <span class={ratingTone(card.rating)}>{label(card.rating ?? '')}</span>
                {early ? <span class="chip chip-warn">Submitted before the interview</span> : null}
              </header>
              {Object.keys(card.attribute_ratings ?? {}).length ? (
                <dl class="scorecard-ratings">
                  {Object.entries(card.attribute_ratings ?? {}).map(([key, rating]) => (
                    <div key={key}>
                      <dt>{attributeName(rubric, key)}</dt>
                      <dd>{attributeValue(rating)}</dd>
                    </div>
                  ))}
                </dl>
              ) : null}
              {card.notes ? <p class="scorecard-notes">{card.notes}</p> : null}
              {card.can_edit && viewer.canWrite ? (
                <details class="scorecard-edit">
                  <summary>{own ? 'Edit your feedback' : `Edit ${author}’s feedback`}</summary>
                  {own ? null : (
                    <p class="sub">
                      This stays {author}’s feedback. Your change is recorded in the audit history.
                    </p>
                  )}
                  <ScorecardForm {...formProps} card={card} />
                </details>
              ) : null}
            </article>
          )
        })}
        {hidden ? (
          <p class="sub">
            {state.onPanel && !state.mine
              ? `${hidden} more ${hidden === 1 ? 'scorecard is' : 'scorecards are'} in. You can read ${hidden === 1 ? 'it' : 'them'} once you submit your own.`
              : `${hidden} ${hidden === 1 ? 'scorecard is' : 'scorecards are'} in. Feedback is shared with the interview panel and the hiring team.`}
          </p>
        ) : null}
        {state.owed ? (
          <section class="scorecard-own" aria-label="Your feedback">
            <h4>Your feedback</h4>
            {state.early ? (
              <p class="sub">
                Demo only: you can submit feedback before the interview. Live workspaces wait until it starts.
              </p>
            ) : null}
            <ScorecardForm {...formProps} />
          </section>
        ) : viewer.canWrite && state.onPanel && !state.mine && !state.cancelled ? (
          <p class="sub">
            {state.scheduled && interview.starts_at
              ? `Your feedback opens when the interview starts (${interviewTime(interview.starts_at)}).`
              : 'Your feedback opens once this interview is scheduled and has started.'}
          </p>
        ) : null}
      </details>
    )
  }
}

/** New feedback, or a correction when `card` is given. Posts to the application's own action. */
function ScorecardForm(
  handle: Handle<{
    action: string
    applicationId: string
    interviewId: string
    rubric?: ScorecardRubric
    card?: Scorecard
    returnToInterview?: boolean
  }>,
) {
  return () => {
    const { action, applicationId, interviewId, rubric, card, returnToInterview } = handle.props
    const id = card ? `${interviewId}-${card.id}` : interviewId
    const rating = card?.rating ?? ''
    return (
      <form method="post" action={action} class="scorecard-form">
        <input type="hidden" name="application_id" value={applicationId} />
        <input type="hidden" name="intent" value="scorecard" />
        <input type="hidden" name="interview_id" value={interviewId} />
        {card ? <input type="hidden" name="scorecard_id" value={card.id} /> : null}
        {returnToInterview ? <input type="hidden" name="after" value="interview" /> : null}
        <label class="field">
          <span>Overall recommendation</span>
          <select name="rating" aria-label="Overall recommendation" required>
            <option value="">Choose a rating</option>
            {RATINGS.map((value) => (
              <option key={value} value={value} selected={rating === value}>
                {label(value)}
              </option>
            ))}
          </select>
        </label>
        {rubric ? (
          <fieldset class="scorecard-rubric">
            <legend>{rubric.name}</legend>
            {rubric.guidance ? <p class="sub">{rubric.guidance}</p> : null}
            <div class="scorecard-rubric-grid">
              {(rubric.attributes_spec ?? []).map((attribute) => {
                const text = attribute.label ?? attribute.name ?? label(attribute.key)
                const score = attributeScore(card?.attribute_ratings?.[attribute.key])
                return (
                  <label key={attribute.key} class="field">
                    <span>
                      {text}
                      {attribute.required === false ? <span class="field-optional"> · optional</span> : null}
                    </span>
                    <select
                      name={`attribute_${attribute.key}`}
                      aria-label={text}
                      required={attribute.required !== false}
                    >
                      <option value="">Choose a score</option>
                      {SCORES.map(([value, text]) => (
                        <option key={value} value={value} selected={score === value}>
                          {text}
                        </option>
                      ))}
                    </select>
                    {attribute.guidance ? <span class="list-meta">{attribute.guidance}</span> : null}
                  </label>
                )
              })}
            </div>
          </fieldset>
        ) : null}
        <label class="field">
          <span>Interview notes</span>
          <textarea name="notes" id={`interview-notes-${id}`} rows={4} defaultValue={card?.notes ?? ''} />
        </label>
        <button class="btn btn-primary" type="submit">
          {card ? 'Save changes' : 'Submit feedback'}
        </button>
      </form>
    )
  }
}
