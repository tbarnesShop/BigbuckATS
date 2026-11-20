import type { Handle } from 'remix/component'
import type { ApplicationFormPayload, Job, JobPosting, QuestionTemplate } from '../../data/api.ts'
import { jobWorkspaceHref } from '../../data/board.ts'
import { label, statusTone } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { Shell } from '../../ui/shell.tsx'
import { QuestionEditor } from './question-editor.tsx'

export type PostingDraft = Pick<
  JobPosting,
  'title' | 'audience' | 'status' | 'questions' | 'description' | 'location' | 'employment_type'
> & {
  templateChoice: string
}
export function JobPostingsPage(
  handle: Handle<{
    job: Job
    postings: JobPosting[]
    templates: QuestionTemplate[]
    baseline: ApplicationFormPayload
    draft?: PostingDraft
    editingId?: string
    error?: string
    notice?: string
    slug?: string
    canManage: boolean
  }>,
) {
  return () => {
    const { job, postings, templates, baseline, draft, editingId, error, notice, slug, canManage } =
      handle.props
    return (
      <Shell
        title={`${job.title} postings`}
        eyebrow="Job"
        backHref={jobWorkspaceHref(job.id, '', { tab: 'settings' })}
        backLabel="Job settings"
      >
        <div class="record-workspace postings-workspace">
          <p class="sub">
            Each posting has its own audience and application form. All applications enter this job's
            pipeline.
          </p>
          <p>
            <a href={routes.questionTemplates.index.href()}>Manage question templates</a>
          </p>
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
          <section class="record-section">
            <h2>Organization questions — always included first</h2>
            <details class="posting-baseline">
              <summary>View organization requirements</summary>
              <p class="sub">
                Required information: {baseline.required_fields.join(', ')}. Posting editors cannot remove
                these requirements.
              </p>
              {baseline.screening_questions.length ? (
                <ol>
                  {baseline.screening_questions.map((q) => (
                    <li key={q.key}>
                      {q.label}
                      {q.required ? ' (required)' : ''}
                    </li>
                  ))}
                </ol>
              ) : (
                <p class="sub">No organization screening questions configured.</p>
              )}
            </details>
          </section>
          <h2>
            Postings <span class="tab-count">{postings.length} shown</span>
          </h2>
          {postings.map((posting) => {
            const query = new URLSearchParams({
              ...(slug ? { slug } : {}),
              posting_id: posting.id,
            }).toString()
            return (
              <section class="record-section posting-row" key={posting.id}>
                <div class="posting-heading">
                  <h3>{posting.title}</h3>
                  <span class={statusTone(posting.status)}>{label(posting.status)}</span>
                </div>
                <p class="list-meta">
                  {[
                    audienceLabel(posting.audience),
                    posting.location,
                    posting.employment_type && label(posting.employment_type),
                  ]
                    .filter(Boolean)
                    .join(' · ')}{' '}
                  · version {posting.version}
                </p>
                {posting.status === 'published' && job.status === 'active' && !job.confidential ? (
                  <p class="posting-links">
                    {['public', 'both'].includes(posting.audience) ? (
                      <a href={`${routes.careersApply.index.href({ jobId: job.id })}?${query}`}>
                        Open external application
                      </a>
                    ) : null}{' '}
                    {['internal', 'both'].includes(posting.audience) ? (
                      <a
                        href={`${routes.internalCareersApply.index.href({ jobId: job.id })}?posting_id=${posting.id}`}
                      >
                        Open internal application
                      </a>
                    ) : null}
                  </p>
                ) : null}
                <details>
                  <summary>Preview application questions</summary>
                  <h4>1. Organization questions</h4>
                  <ol>
                    {baseline.screening_questions.map((q) => (
                      <li key={q.key}>
                        {q.label}
                        {q.required ? ' (required)' : ''}
                      </li>
                    ))}
                  </ol>
                  <h4>2. Template questions (saved version {posting.template_version ?? '—'})</h4>
                  <ol>
                    {(posting.template_questions ?? []).map((q) => (
                      <li key={q.key}>
                        {q.label}
                        {q.required ? ' (required)' : ''}
                      </li>
                    ))}
                  </ol>
                  <h4>3. Posting questions</h4>
                  <ol>
                    {(posting.questions ?? []).map((q) => (
                      <li key={q.key}>
                        {q.label}
                        {q.required ? ' (required)' : ''}
                      </li>
                    ))}
                  </ol>
                </details>
                {canManage ? (
                  <details class="posting-edit" open={editingId === posting.id}>
                    <summary>Edit posting</summary>
                    <PostingEditor
                      jobId={job.id}
                      posting={posting}
                      templates={templates}
                      draft={editingId === posting.id ? draft : undefined}
                    />
                  </details>
                ) : null}
              </section>
            )
          })}
          {canManage ? (
            <details
              class="record-section posting-edit posting-create"
              open={!postings.length || editingId === 'new'}
            >
              <summary>New posting</summary>
              <PostingEditor
                jobId={job.id}
                templates={templates}
                draft={editingId === 'new' ? draft : undefined}
              />
            </details>
          ) : null}
        </div>
      </Shell>
    )
  }
}
function PostingEditor(
  handle: Handle<{
    jobId: string
    posting?: JobPosting
    templates: QuestionTemplate[]
    draft?: PostingDraft
  }>,
) {
  return () => {
    const { jobId, posting, templates, draft } = handle.props
    const row = draft ?? {
      title: posting?.title ?? '',
      audience: posting?.audience ?? 'public',
      status: posting?.status ?? 'draft',
      questions: posting?.questions ?? [],
      description: posting?.description ?? '',
      location: posting?.location ?? '',
      employment_type: posting?.employment_type ?? '',
      templateChoice: posting ? 'keep' : '',
    }
    return (
      <form class="posting-form" method="post" action={routes.jobPostings.action.href({ jobId })}>
        <input type="hidden" name="posting_id" value={posting?.id ?? ''} />
        <input type="hidden" name="expected_version" value={posting?.version ?? ''} />
        <div class="posting-fields">
          <label class="field posting-title">
            <span>Posting title</span>
            <input name="title" defaultValue={row.title} required maxLength={255} />
          </label>
          <label class="field">
            <span>Posting audience</span>
            <select name="audience" aria-label="Posting audience">
              {['public', 'internal', 'both', 'hidden'].map((value) => (
                <option key={value} value={value} selected={value === row.audience}>
                  {audienceLabel(value)}
                </option>
              ))}
            </select>
          </label>
          <label class="field">
            <span>Posting status</span>
            <select name="status" aria-label="Posting status">
              {['draft', 'published', 'archived'].map((value) => (
                <option key={value} value={value} selected={value === row.status}>
                  {label(value)}
                </option>
              ))}
            </select>
          </label>
          <label class="field posting-template">
            <span>Question template</span>
            <select name="template_choice" aria-label="Question template">
              {posting ? (
                <option value="keep" selected={row.templateChoice === 'keep'}>
                  Keep saved template questions
                </option>
              ) : null}
              <option value="" selected={row.templateChoice === ''}>
                No template
              </option>
              {templates
                .filter((t) => t.status === 'active')
                .map((t) => (
                  <option key={t.id} value={t.id} selected={row.templateChoice === t.id}>
                    {t.name} · {t.owner_name} · v{t.version}
                  </option>
                ))}
            </select>
          </label>
        </div>
        <div class="form-row">
          <label class="field">
            <span>Location</span>
            <input
              name="location"
              defaultValue={row.location ?? ''}
              placeholder="Remote — US"
              maxLength={255}
            />
          </label>
          <label class="field">
            <span>Employment type</span>
            <select name="employment_type">
              <option value="">Not specified</option>
              {['full_time', 'part_time', 'contract', 'internship', 'temporary'].map((value) => (
                <option key={value} value={value} selected={value === row.employment_type}>
                  {label(value)}
                </option>
              ))}
            </select>
          </label>
        </div>
        <label class="field">
          <span>Job description</span>
          <textarea name="description" rows={8} defaultValue={row.description ?? ''} maxLength={20000} />
        </label>
        <p class="sub">
          Selecting a template copies its current questions when you save. Existing snapshots stay unchanged
          until you select a template again.
        </p>
        <h4>Additional questions for this posting</h4>
        <QuestionEditor questions={row.questions} />
        <p>
          <button class="btn btn-primary" type="submit" name="intent" value="save">
            {posting ? 'Save posting' : 'Create posting'}
          </button>
        </p>
      </form>
    )
  }
}

function audienceLabel(value: string) {
  return (
    (
      {
        public: 'Public',
        internal: 'Internal employees',
        both: 'Public and internal',
        hidden: 'Hidden',
      } as Record<string, string>
    )[value] ?? value
  )
}
