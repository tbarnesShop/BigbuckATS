import type { Handle } from 'remix/component'

import type { Job, RediscoveryCandidate, RediscoveryCriterion, Sequence } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FilterSegments } from '../../ui/page-chrome.tsx'
import { EmptyState, Shell } from '../../ui/shell.tsx'

const REVIEW_ACTIONS: Array<[string, string]> = [
  ['consider', 'Consider'],
  ['add_to_pool', 'Add to pool'],
  ['review_later', 'Later'],
  ['not_a_fit', 'Not a fit'],
]

function matchText(match: Record<string, string>) {
  return Object.entries(match)
    .map(([key, value]) => `${key === 'q' ? 'Any words' : label(key)}: ${value}`)
    .join(', ')
}

export function RediscoveryPage(
  handle: Handle<{
    job: Pick<Job, 'id' | 'title'>
    criteria: RediscoveryCriterion[]
    candidates: RediscoveryCandidate[]
    buckets: Record<string, number>
    bucket: string
    sequences: Sequence[]
    canManage: boolean
    canEnroll: boolean
    orgQuery?: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let {
      job,
      criteria,
      candidates,
      buckets,
      bucket,
      sequences,
      canManage,
      canEnroll,
      orgQuery = '',
      notice,
      error,
    } = handle.props
    let action = `${routes.jobRediscovery.action.href({ jobId: job.id })}${orgQuery}`
    let base = `${routes.jobRediscovery.index.href({ jobId: job.id })}`
    return (
      <Shell
        title="Rediscovery"
        sub={`${job.title}: people already in your CRM who fit this role`}
        backHref={`${routes.jobsShow.index.href({ jobId: job.id })}${orgQuery}`}
        backLabel="Job"
        orgQuery={orgQuery}
      >
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
        <section class="section-card" aria-label="Criteria">
          <h2>What good looks like</h2>
          {criteria.length === 0 ? (
            <p class="hint">No criteria yet. Add a must-have or nice-to-have to start matching.</p>
          ) : (
            <ul class="today-rows">
              {criteria.map((criterion) => (
                <li key={criterion.id}>
                  <div class="today-row-body">
                    <span class="today-row-title">{criterion.label}</span>
                    <span class="meta">
                      {criterion.kind === 'must' ? 'Must have' : 'Nice to have'} ·{' '}
                      {matchText(criterion.match)}
                    </span>
                  </div>
                  {canManage ? (
                    <form method="post" action={action}>
                      <input type="hidden" name="remove_id" value={criterion.id} />
                      <button
                        class="btn btn-ghost btn-small"
                        type="submit"
                        name="intent"
                        value="remove_criterion"
                      >
                        Remove
                      </button>
                    </form>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
          {canManage ? (
            <details class="workflow-disclosure">
              <summary>Add a criterion</summary>
              <form method="post" action={action} class="form-narrow">
                <input type="hidden" name="intent" value="add_criterion" />
                <label class="field">
                  <span>Label</span>
                  <input name="label" required maxLength={120} />
                </label>
                <label class="field">
                  <span>Importance</span>
                  <select name="kind">
                    <option value="must">Must have</option>
                    <option value="nice">Nice to have</option>
                  </select>
                </label>
                <label class="field">
                  <span>Match on</span>
                  <select name="match_key">
                    <option value="tag">Tag</option>
                    <option value="title">Title contains</option>
                    <option value="location">Location</option>
                    <option value="company">Company</option>
                    <option value="q">Any words</option>
                  </select>
                </label>
                <label class="field">
                  <span>Value</span>
                  <input name="match_value" required />
                </label>
                <button class="btn btn-primary" type="submit">
                  Add criterion
                </button>
              </form>
            </details>
          ) : null}
          {canManage && criteria.length > 0 ? (
            <form method="post" action={action} class="row-actions">
              <button class="btn btn-primary" type="submit" name="intent" value="run">
                Find matches
              </button>
            </form>
          ) : null}
        </section>
        <section class="section-card" aria-label="Review queue">
          <h2>Review queue</h2>
          <FilterSegments
            label="Buckets"
            links={[
              { href: `${base}${orgQuery}`, label: 'All', current: bucket === '' },
              ...Object.entries(buckets).map(([key, count]) => ({
                href: `${base}?bucket=${key}${orgQuery.replace('?', '&')}`,
                label: label(key),
                current: bucket === key,
                count,
              })),
            ]}
          />
          {candidates.length === 0 ? (
            <EmptyState>Nobody to review. Add criteria and run Find matches.</EmptyState>
          ) : (
            <form method="post" action={action}>
              <input type="hidden" name="bucket" value={bucket} />
              {canEnroll && sequences.length > 0 ? (
                <label class="field">
                  <span>Sequence for Enroll</span>
                  <select name="sequence_id">
                    {sequences.map((sequence) => (
                      <option key={sequence.id} value={sequence.id}>
                        {sequence.name}
                      </option>
                    ))}
                  </select>
                </label>
              ) : null}
              <ul class="queue">
                {candidates.map((candidate) => (
                  <li key={candidate.id} class="queue-item">
                    <div class="body">
                      <span class="title">
                        <a href={`/people/${candidate.person_id}${orgQuery}`}>
                          {candidate.person?.display_name ?? 'Person'}
                        </a>
                      </span>
                      <span class="hint">
                        {label(candidate.bucket)} · score {Math.round(candidate.score)} ·{' '}
                        {label(candidate.status)}
                        {candidate.reasons?.length
                          ? ` · ${candidate.reasons.map((reason) => label(reason)).join(' · ')}`
                          : ''}
                      </span>
                    </div>
                    {canManage ? (
                      <span class="row-actions">
                        {REVIEW_ACTIONS.map(([value, text]) => (
                          <button
                            key={value}
                            class="btn btn-ghost btn-small"
                            type="submit"
                            name="intent"
                            value={`review:${candidate.id}:${value}`}
                          >
                            {text}
                          </button>
                        ))}
                        {canEnroll && sequences.length > 0 ? (
                          <button
                            class="btn btn-primary btn-small"
                            type="submit"
                            name="intent"
                            value={`review:${candidate.id}:enroll`}
                          >
                            Enroll
                          </button>
                        ) : null}
                      </span>
                    ) : null}
                  </li>
                ))}
              </ul>
            </form>
          )}
        </section>
      </Shell>
    )
  }
}
