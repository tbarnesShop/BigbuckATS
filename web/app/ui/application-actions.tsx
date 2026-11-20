import type { Handle } from 'remix/component'
import type { Application } from '../data/api.ts'
import { archiveReasons } from '../data/application-archive.ts'
import { stageLabel } from '../data/board.ts'
import { signedIn } from '../data/auth.ts'
import { RecordActionMenu } from './record-action-menu.tsx'

export function ApplicationActions(
  handle: Handle<{
    applications: Application[]
    actionFor: (id: string) => string
    error?: boolean
    archiveError?: boolean
    archiveReasonKey?: string
    guidance?: string
    toStageKey?: string
    allowHire?: boolean
  }>,
) {
  return () => {
    const { applications, actionFor, guidance, toStageKey, allowHire } = handle.props
    const active = applications.filter((application) => application.status === 'active')
    if (!signedIn()?.permissions?.includes('application.move_stage') || !active.length) return null
    // Mark hired is its own visible control, never an item hidden in the Move menu, and it appears
    // only once an offer is accepted: the same rule the API enforces.
    const hireable = allowHire
      ? active.filter((application) => application.offers?.some((offer) => offer.status === 'accepted'))
      : []
    return (
      <div class="candidate-actions" role="group" aria-label="Candidate actions">
        {hireable.map((application) => (
          <form
            key={`hire-${application.id}`}
            method="post"
            action={actionFor(application.id)}
            data-application-id={application.id}
          >
            <input type="hidden" name="intent" value="transition" />
            <input type="hidden" name="command" value="hire" />
            <button
              class="btn btn-primary"
              type="submit"
              aria-label={
                hireable.length > 1 ? `Mark hired for ${application.job?.title ?? 'this job'}` : undefined
              }
            >
              Mark hired
            </button>
          </form>
        ))}
        <RecordActionMenu label="Move candidate" initiallyOpen={handle.props.error}>
          {guidance ? <p class="sub">{guidance}</p> : null}
          {active.map((application) => {
            const stages = application.pipeline?.stages ?? []
            return (
              <div key={application.id} class="candidate-action-group">
                <h3>{application.job?.title ?? 'Job application'}</h3>
                <form method="post" action={actionFor(application.id)} data-application-id={application.id}>
                  <input type="hidden" name="intent" value="transition" />
                  <input type="hidden" name="command" value="move" />
                  <input type="hidden" name="application_id" value={application.id} />
                  <label class="field">
                    <span>To stage</span>
                    <select name="to_stage_key" aria-label="To stage" required>
                      <option value="">Choose a stage</option>
                      {stages
                        .filter(
                          (stage) => stage.key !== application.current_stage_key && stage.type !== 'hired',
                        )
                        .map((stage) => (
                          <option
                            key={stage.key}
                            value={stage.key}
                            selected={Boolean(toStageKey) && stage.key === toStageKey}
                          >
                            {stageLabel(stage, stage.key)}
                          </option>
                        ))}
                    </select>
                  </label>
                  <label class="field">
                    <span>Reason (optional)</span>
                    <input name="reason" type="text" />
                  </label>
                  <button class="btn btn-primary" type="submit">
                    Move candidate
                  </button>
                </form>
              </div>
            )
          })}
        </RecordActionMenu>
        <RecordActionMenu label="Archive application" initiallyOpen={handle.props.archiveError}>
          <p class="sub">Closes this job application. The person and their history are kept.</p>
          {active.map((application) => (
            <div key={application.id} class="candidate-action-group">
              <h3>{application.job?.title ?? 'Job application'}</h3>
              <form method="post" action={actionFor(application.id)} data-application-id={application.id}>
                <input type="hidden" name="intent" value="archive" />
                <input type="hidden" name="application_id" value={application.id} />
                <label class="field">
                  <span>Archive reason</span>
                  <select name="archive_reason" aria-label="Archive reason" required>
                    <option value="">Choose a reason</option>
                    {archiveReasons.map((reason) => (
                      <option
                        key={reason.key}
                        value={reason.key}
                        selected={reason.key === handle.props.archiveReasonKey}
                      >
                        {reason.label}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-primary" type="submit">
                  Archive application
                </button>
              </form>
            </div>
          ))}
        </RecordActionMenu>
      </div>
    )
  }
}
