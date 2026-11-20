import type { Handle } from 'remix/component'

import type { AgentProposal, Job, Sequence } from '../../data/api.ts'
import { label, whenLabel } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { FilterSegments } from '../../ui/page-chrome.tsx'
import { EmptyState, Shell } from '../../ui/shell.tsx'

export type ProposalView = 'pending' | 'approved' | 'rejected'

const VIEWS: Array<[ProposalView, string]> = [
  ['pending', 'To review'],
  ['approved', 'Approved'],
  ['rejected', 'Rejected'],
]

function rationaleText(value: AgentProposal['rationale']) {
  if (!value) return ''
  if (typeof value === 'string') return value
  let reasons = (value as { reasons?: unknown }).reasons
  if (Array.isArray(reasons)) return reasons.map((reason) => label(String(reason))).join(' · ')
  return Object.values(value)
    .filter((item) => typeof item === 'string')
    .join(' · ')
}

export function ProposalsPage(
  handle: Handle<{
    proposals: AgentProposal[]
    counts: Record<string, number>
    view: ProposalView
    jobs: Job[]
    sequences: Sequence[]
    canDecide: boolean
    canRun: boolean
    orgQuery?: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let {
      proposals,
      counts,
      view,
      jobs,
      sequences,
      canDecide,
      canRun,
      orgQuery = '',
      notice,
      error,
    } = handle.props
    let action = `${routes.proposals.action.href()}${orgQuery}`
    let pending = view === 'pending'
    return (
      <Shell title="Approvals" sub="Nothing is sent until you approve." orgQuery={orgQuery}>
        <FoldSectionTabs label="Today sections" parent="today" orgQuery={orgQuery} />
        <FilterSegments
          label="Proposal views"
          links={VIEWS.map(([value, text]) => ({
            href: `${routes.proposals.index.href()}?view=${value}${orgQuery.replace('?', '&')}`,
            label: text,
            current: value === view,
            count: counts[value] || undefined,
          }))}
        />
        {notice ? (
          <p class="notice" role="status">
            {notice}
          </p>
        ) : null}
        {error ? (
          <p class="error" role="alert">
            {error}
          </p>
        ) : null}
        {canRun ? (
          <details class="workflow-disclosure">
            <summary>Run the sourcing agent</summary>
            <form method="post" action={action} class="form-narrow">
              <input type="hidden" name="intent" value="run" />
              <label class="field">
                <span>Job</span>
                <select name="job_id" required>
                  {jobs.map((job) => (
                    <option key={job.id} value={job.id}>
                      {job.title}
                    </option>
                  ))}
                </select>
              </label>
              <label class="field">
                <span>Sequence</span>
                <select name="sequence_id" required>
                  {sequences.map((sequence) => (
                    <option key={sequence.id} value={sequence.id}>
                      {sequence.name}
                    </option>
                  ))}
                </select>
              </label>
              <label class="field">
                <span>How many people</span>
                <input name="limit" type="number" min="1" max="50" value="10" />
              </label>
              <button class="btn btn-primary" type="submit">
                Find people
              </button>
            </form>
          </details>
        ) : null}
        {proposals.length === 0 ? (
          <EmptyState>
            {pending ? 'Run the sourcing agent for a job to get proposals.' : 'None yet.'}
          </EmptyState>
        ) : (
          <form method="post" action={action}>
            <input type="hidden" name="view" value={view} />
            {pending && canDecide ? (
              <p class="row-actions">
                <button class="btn btn-primary btn-small" type="submit" name="intent" value="bulk_approve">
                  Approve selected
                </button>
                <span class="hint">Select rows below, or open one to edit its opener first.</span>
              </p>
            ) : null}
            <ul class="queue">
              {proposals.map((proposal) => (
                <li key={proposal.id} class="queue-item">
                  <div class="body">
                    <span class="title">
                      {pending && canDecide ? (
                        <input
                          type="checkbox"
                          name="ids"
                          value={proposal.id}
                          aria-label={`Select ${proposal.person?.display_name ?? 'person'}`}
                        />
                      ) : null}{' '}
                      <a href={`/people/${proposal.person_id}${orgQuery}`}>
                        {proposal.person?.display_name ?? 'Person'}
                      </a>
                    </span>
                    <span class="hint">
                      {rationaleText(proposal.rationale)}
                      {proposal.agent?.name ? ` · ${proposal.agent.name}` : ''}
                      {' · '}
                      {whenLabel(proposal.created_at)}
                      {proposal.status !== 'pending' ? ` · ${label(proposal.status)}` : ''}
                    </span>
                    {pending && canDecide ? (
                      <details>
                        <summary>Opener</summary>
                        <label class="field">
                          <span class="visually-hidden">Opener for {proposal.person?.display_name}</span>
                          <textarea
                            name={`opener_${proposal.id}`}
                            rows={4}
                            defaultValue={proposal.draft_opener ?? ''}
                          />
                        </label>
                      </details>
                    ) : (
                      <p class="hint">{proposal.final_opener ?? proposal.draft_opener ?? ''}</p>
                    )}
                  </div>
                  {pending && canDecide ? (
                    <span class="row-actions">
                      <button
                        class="btn btn-primary btn-small"
                        type="submit"
                        name="intent"
                        value={`approve:${proposal.id}`}
                      >
                        Approve
                      </button>
                      <button
                        class="btn btn-ghost btn-small"
                        type="submit"
                        name="intent"
                        value={`reject:${proposal.id}`}
                      >
                        Reject
                      </button>
                    </span>
                  ) : null}
                </li>
              ))}
            </ul>
          </form>
        )}
      </Shell>
    )
  }
}
