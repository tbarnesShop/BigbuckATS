import type { Handle } from 'remix/component'
import { unsafeHTML } from 'remix/component'

import type { CareersPage, ScreeningQuestion } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { CandidateFrame } from '../../ui/candidate-frame.tsx'
import { HeroMedia } from '../../ui/hero-media.tsx'
import { Field, PrimaryButton, Shell } from '../../ui/shell.tsx'

function dimension(job: CareersPage['jobs'][number], key: string) {
  const value =
    job[key === 'department' ? 'department' : 'location'] ??
    job.dimensions?.find((row) => row.key === key)?.value ??
    null
  return value ? normalizeDashes(value) : null
}

/** "Remote - US", "Remote – US" and "Remote — US" are one place: one filter option, one label. */
export function normalizeDashes(value: string): string {
  return value.replace(/\s+[-–—]+\s+/g, ' — ').trim()
}

type CareersJob = CareersPage['jobs'][number]

function jobMeta(job: CareersJob): string {
  return [dimension(job, 'location'), job.employment_type ? label(job.employment_type) : null]
    .filter(Boolean)
    .join(' · ')
}

/** Readable text on an employer accent: near-black on light accents, white on dark ones. */
export function onAccent(hex: string): string {
  let [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
  let lin = (c: number) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)
  let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
  return luminance > 0.36 ? '#06201d' : '#ffffff'
}

export function CareersIndexPage(
  handle: Handle<{
    careers: CareersPage
    orgQuery: string
    department?: string
    location?: string
    internal?: boolean
  }>,
) {
  return () => {
    let { careers, orgQuery, department = '', location = '', internal = false } = handle.props
    let all = careers.jobs.filter((job) => job.status === 'active')
    let active = all
    let departments = [
      ...new Set(all.map((job) => dimension(job, 'department')).filter(Boolean)),
    ].sort() as string[]
    let locations = [
      ...new Set(all.map((job) => dimension(job, 'location')).filter(Boolean)),
    ].sort() as string[]
    if (department) active = active.filter((job) => dimension(job, 'department') === department)
    if (location) active = active.filter((job) => dimension(job, 'location') === location)
    let groups = new Map<string, CareersJob[]>()
    for (let job of [...active].sort((a, b) => a.title.localeCompare(b.title))) {
      let key = dimension(job, 'department') ?? 'Other roles'
      groups.set(key, [...(groups.get(key) ?? []), job])
    }
    let grouped = [...groups].sort(([a], [b]) =>
      a === 'Other roles' ? 1 : b === 'Other roles' ? -1 : a.localeCompare(b),
    )
    let culture = careers.careers.culture?.length
      ? careers.careers.culture
      : [
          { title: 'How we work', body: 'Small teams, clear ownership, and a hiring loop you can see.' },
          {
            title: 'How we hire',
            body: 'A conversation, a work sample, and a decision with the people you would work with.',
          },
        ]
    let jsonLd = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      itemListElement: active.map((job, index) => ({
        '@type': 'ListItem',
        position: index + 1,
        item: {
          '@type': 'JobPosting',
          title: job.title,
          description: job.description ?? undefined,
          employmentType: job.employment_type ? job.employment_type.toUpperCase() : undefined,
          hiringOrganization: { '@type': 'Organization', name: careers.organization.name },
          jobLocation: dimension(job, 'location')
            ? { '@type': 'Place', name: dimension(job, 'location') }
            : undefined,
        },
      })),
    }).replace(/</g, '\\u003c')
    let slug = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : '').get('slug')
    let hero = careers.careers.hero_image_url || '/careers-canopy.avif'
    let applyHref = (job: CareersJob) =>
      `${internal ? routes.internalCareersApply.index.href({ jobId: job.id }) : routes.careersApply.index.href({ jobId: job.id })}${internal ? '?' : `${orgQuery}${orgQuery ? '&' : '?'}`}posting_id=${encodeURIComponent(job.posting_id ?? '')}`
    let jobHref = (job: CareersJob) =>
      `${routes.careersJob.href({ jobId: job.id })}${orgQuery}${orgQuery ? '&' : '?'}posting_id=${encodeURIComponent(job.posting_id ?? '')}`
    let filtered = Boolean(department || location)

    let accent = /^#[0-9a-f]{6}$/i.test(careers.careers.accent_color ?? '')
      ? careers.careers.accent_color!
      : null
    let brandStyle = accent ? `--careers-accent:${accent};--careers-on-accent:${onAccent(accent)}` : undefined
    let about = internal ? null : careers.careers.about
    let cultureTitle =
      (!internal && careers.careers.culture_intro?.title) || `Life at ${careers.organization.name}`
    let cultureBody = internal ? '' : (careers.careers.culture_intro?.body ?? '')
    return (
      <Shell title={careers.organization.name} bare>
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Instrument+Serif&display=swap"
        />
        <div class="careers-page" style={brandStyle}>
          <section class="careers-hero" aria-label="Careers">
            <HeroMedia src={hero} alt="" />
            <div class="careers-hero-shade" />
            <div class="careers-hero-inner">
              <p class="careers-brand">
                <img src="/bigbuck-mark.png" alt="" width={32} height={32} />
                <span>{careers.organization.name}</span>
              </p>
              <h1>{internal ? 'Internal opportunities' : careers.careers.headline}</h1>
              <p class="careers-subcopy">
                {internal
                  ? 'Explore your next role. Applications use your signed-in employee identity.'
                  : careers.careers.subcopy}
              </p>
              <a class="careers-cta" href="#openings">
                See open roles{all.length ? ` (${all.length})` : ''}
              </a>
            </div>
          </section>

          {about && (about.title || about.body) ? (
            <section class="careers-section" aria-labelledby="careers-about">
              <div class="careers-section-inner">
                <h2 id="careers-about">{about.title}</h2>
                {about.body ? <p class="careers-lede">{about.body}</p> : null}
              </div>
            </section>
          ) : null}

          <section class="careers-section" aria-labelledby="careers-why">
            <div class="careers-section-inner">
              <h2 id="careers-why">{cultureTitle}</h2>
              {cultureBody ? <p class="careers-lede">{cultureBody}</p> : null}
              <div class="careers-values">
                {culture.map((block) => (
                  <article key={block.title} class="careers-value">
                    <h3>{block.title}</h3>
                    <p>{block.body}</p>
                  </article>
                ))}
              </div>
            </div>
          </section>

          <section class="careers-section careers-roles-band" aria-labelledby="openings">
            <div class="careers-section-inner">
              <div class="careers-roles-head">
                <h2 id="openings">Open roles</h2>
                <p class="careers-lede">
                  {filtered
                    ? `${active.length} of ${all.length} roles match.`
                    : `${all.length} open ${all.length === 1 ? 'role' : 'roles'}.`}
                </p>
              </div>
              {careers.careers.demo ? (
                <p class="demo-disclaimer" role="note">
                  Demo careers page for an invented company. Applications stay in this demo workspace; please
                  do not enter real personal information.
                </p>
              ) : null}
              {departments.length > 1 || locations.length > 1 ? (
                <form
                  class="careers-filters"
                  method="get"
                  action={internal ? routes.internalCareers.href() : routes.careersIndex.href()}
                >
                  {slug ? <input type="hidden" name="slug" value={slug} /> : null}
                  {departments.length > 1 ? (
                    <label class="field">
                      <span>Team</span>
                      <select name="department">
                        <option value="">All teams</option>
                        {departments.map((value) => (
                          <option key={value} value={value} selected={value === department}>
                            {value}
                          </option>
                        ))}
                      </select>
                    </label>
                  ) : null}
                  {locations.length > 1 ? (
                    <label class="field">
                      <span>Location</span>
                      <select name="location">
                        <option value="">All locations</option>
                        {locations.map((value) => (
                          <option key={value} value={value} selected={value === location}>
                            {value}
                          </option>
                        ))}
                      </select>
                    </label>
                  ) : null}
                  <button class="btn btn-ghost btn-small" type="submit">
                    Show roles
                  </button>
                  {filtered ? (
                    <a
                      class="careers-clear"
                      href={`${internal ? routes.internalCareers.href() : routes.careersIndex.href()}${slug ? `?slug=${encodeURIComponent(slug)}` : ''}#openings`}
                    >
                      Clear
                    </a>
                  ) : null}
                </form>
              ) : null}
              {active.length === 0 ? (
                <p class="careers-muted">
                  {all.length === 0
                    ? 'No open roles right now. Check back soon.'
                    : 'No roles match these filters.'}
                </p>
              ) : (
                grouped.map(([group, jobs]) => (
                  <div key={group} class="careers-group">
                    <h3 class="careers-group-title">{group}</h3>
                    <ul class="careers-roles">
                      {jobs.map((job) => (
                        <li key={job.posting_id ?? job.id} class="careers-role">
                          <a class="careers-role-link" href={internal ? applyHref(job) : jobHref(job)}>
                            <span class="careers-role-title">{job.title}</span>
                            {jobMeta(job) ? <span class="careers-role-meta">{jobMeta(job)}</span> : null}
                          </a>
                          <a
                            class="btn btn-primary btn-small careers-apply"
                            href={applyHref(job)}
                            aria-label={`Apply for ${job.title}`}
                          >
                            Apply
                          </a>
                        </li>
                      ))}
                    </ul>
                  </div>
                ))
              )}
            </div>
          </section>

          <footer class="careers-footer">
            <span>© {careers.organization.name}</span>
            {internal ? (
              <a href={`${routes.careersIndex.href()}${orgQuery}`}>Public careers</a>
            ) : (
              <a href={routes.internalCareers.href()}>Employee? See internal roles</a>
            )}
          </footer>
        </div>
        {internal ? null : <script type="application/ld+json" innerHTML={unsafeHTML(jsonLd)} />}
        <style>{`@keyframes bbInkReveal { from { opacity: 0.6; transform: scale(1.03); } to { opacity: 1; transform: scale(1); } }`}</style>
      </Shell>
    )
  }
}

/** Plain-text job description → paragraphs and "- " bullet lists. */
export function DescriptionBlocks(handle: Handle<{ text: string }>) {
  return () => {
    let blocks = handle.props.text
      .split(/\n\s*\n/)
      .map((block) => block.trim())
      .filter(Boolean)
    return (
      <div class="careers-description">
        {blocks.map((block, index) => {
          let lines = block.split('\n').map((line) => line.trim())
          let bullets = lines.filter((line) => /^[-*•]\s+/.test(line))
          if (
            bullets.length &&
            bullets.length === lines.length - (lines[0] && !/^[-*•]\s+/.test(lines[0]) ? 1 : 0)
          ) {
            let heading = /^[-*•]\s+/.test(lines[0] ?? '') ? null : lines[0]
            return (
              <div key={index}>
                {heading ? <h3>{heading}</h3> : null}
                <ul>
                  {bullets.map((line) => (
                    <li key={line}>{line.replace(/^[-*•]\s+/, '')}</li>
                  ))}
                </ul>
              </div>
            )
          }
          return <p key={index}>{lines.join(' ')}</p>
        })}
      </div>
    )
  }
}

export function submittedValues(form: FormData): Record<string, string | string[]> {
  return Object.fromEntries(
    [...new Set(form.keys())].map((key) => {
      const values = form.getAll(key).map(String)
      return [key, values.length > 1 ? values : (values[0] ?? '')]
    }),
  )
}

function QuestionField(handle: Handle<{ question: ScreeningQuestion; value?: string | string[] }>) {
  return () => {
    let question = handle.props.question
    let options = question.options ?? []
    let value = handle.props.value
    let selected = (option: string) => (Array.isArray(value) ? value.includes(option) : value === option)
    let text = Array.isArray(value) ? value.join(', ') : value
    return (
      <label class="field">
        <span>
          {question.label}
          {question.required ? ' (required)' : ''}
        </span>
        {question.field_type === 'boolean' ? (
          <select name={question.key} required={question.required}>
            <option value="">Choose</option>
            <option value="true" selected={selected('true')}>
              Yes
            </option>
            <option value="false" selected={selected('false')}>
              No
            </option>
          </select>
        ) : question.field_type === 'long_text' ? (
          <textarea name={question.key} required={question.required} defaultValue={text} rows={4} />
        ) : options.length > 0 ? (
          <select
            name={question.key}
            required={question.required}
            multiple={question.field_type === 'multi_select'}
          >
            {question.field_type !== 'multi_select' ? <option value="">Choose</option> : null}
            {options.map((option) => {
              let value = typeof option === 'string' ? option : option.key
              let label = typeof option === 'string' ? option : option.label
              return (
                <option key={value} value={value} selected={selected(value)}>
                  {label}
                </option>
              )
            })}
          </select>
        ) : question.field_type === 'number' ? (
          <input
            name={question.key}
            defaultValue={text}
            type="number"
            step="any"
            required={question.required}
          />
        ) : question.field_type === 'email' ? (
          <input name={question.key} defaultValue={text} type="email" required={question.required} />
        ) : question.field_type === 'url' ? (
          <input name={question.key} defaultValue={text} type="url" required={question.required} />
        ) : (
          <input name={question.key} defaultValue={text} type="text" required={question.required} />
        )}
      </label>
    )
  }
}

export function CareersApplyPage(
  handle: Handle<{
    postingId?: string
    jobId: string
    jobTitle: string
    orgName: string
    slug: string
    orgQuery: string
    internal?: boolean
    employeeName?: string
    employeeEmail?: string
    questions: ScreeningQuestion[]
    required: string[]
    description?: string | null
    meta?: string
    /** False when this demo workspace does not take applications from the public page. */
    acceptsApplications?: boolean
    error?: string
    values?: Record<string, string | string[]>
    success?: string
  }>,
) {
  return () => {
    let {
      jobId,
      jobTitle,
      orgName,
      slug,
      orgQuery,
      questions,
      required,
      postingId,
      error,
      success,
      internal = false,
      employeeName,
      employeeEmail,
      description,
      meta,
      acceptsApplications = true,
    } = handle.props
    const values = handle.props.values ?? {}
    const standardValue = (key: string) => String(values[key] ?? '')
    const organizationQuestions = questions.filter(
      (q) => !q.key.startsWith('template.') && !q.key.startsWith('posting.'),
    )
    const roleQuestions = questions.filter(
      (q) => q.key.startsWith('template.') || q.key.startsWith('posting.'),
    )
    let needs = new Set(required.length ? required : ['display_name', 'email'])
    return (
      <CandidateFrame
        title={jobTitle}
        orgName={orgName}
        slug={slug}
        kicker={internal ? 'Internal application' : 'Apply'}
        careersHref={internal ? routes.internalCareers.href() : undefined}
      >
        {meta ? <p class="careers-role-meta">{meta}</p> : null}
        {description && !success ? (
          <details class="careers-about" open>
            <summary>About the role</summary>
            <DescriptionBlocks text={description} />
          </details>
        ) : null}
        {!acceptsApplications && !success ? (
          <p class="demo-disclaimer" role="note">
            This demo workspace is not taking applications from the public careers page. Employees can apply
            from internal careers, and recruiters can add candidates from a job's Sourcing tab.
          </p>
        ) : null}
        {success ? (
          <div class="candidate-success" role="status">
            <h2>Application received</h2>
            <p>{success}</p>
          </div>
        ) : (
          <>
            {error ? (
              <p class="notice-bad" role="alert">
                {error}
              </p>
            ) : null}
            <form
              method="post"
              action={`${internal ? routes.internalCareersApply.action.href({ jobId }) : routes.careersApply.action.href({ jobId })}${internal ? '?' : `${orgQuery}${orgQuery ? '&' : '?'}`}posting_id=${encodeURIComponent(postingId ?? '')}`}
            >
              {internal ? (
                <p>
                  Applying as {employeeName} ({employeeEmail}).
                </p>
              ) : (
                <>
                  <Field
                    label="Full name"
                    name="display_name"
                    defaultValue={standardValue('display_name')}
                    required
                  />
                  <Field label="Email" name="email" defaultValue={standardValue('email')} email required />
                </>
              )}
              <Field
                label={needs.has('phone') ? 'Phone' : 'Phone (optional)'}
                name="phone"
                defaultValue={standardValue('phone')}
                required={needs.has('phone')}
              />
              <Field
                label={needs.has('linkedin') ? 'LinkedIn' : 'LinkedIn (optional)'}
                name="linkedin"
                defaultValue={standardValue('linkedin')}
                required={needs.has('linkedin')}
              />
              <Field
                label={
                  needs.has('links') ? 'Portfolio or other links' : 'Portfolio or other links (optional)'
                }
                name="links"
                defaultValue={standardValue('links')}
                required={needs.has('links')}
              />
              {needs.has('country') ? (
                <Field label="Country" name="country" defaultValue={standardValue('country')} required />
              ) : null}
              {needs.has('region') ? (
                <Field label="Region" name="region" defaultValue={standardValue('region')} required />
              ) : null}
              {organizationQuestions.length ? (
                <section>
                  <h2>Organization questions</h2>
                  {organizationQuestions.map((question) => (
                    <QuestionField key={question.key} question={question} value={values[question.key]} />
                  ))}
                </section>
              ) : null}
              {roleQuestions.length ? (
                <section>
                  <h2>About this role</h2>
                  {roleQuestions.map((question) => (
                    <QuestionField key={question.key} question={question} value={values[question.key]} />
                  ))}
                </section>
              ) : null}
              {acceptsApplications ? <PrimaryButton type="submit">Submit application</PrimaryButton> : null}
            </form>
          </>
        )}
        <p>
          <a href={internal ? routes.internalCareers.href() : `${routes.careersIndex.href()}${orgQuery}`}>
            ← All openings
          </a>
        </p>
      </CandidateFrame>
    )
  }
}

/** A sentence an applicant can act on, never an API error string. */
export function applyError(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error)
  if (message.includes('turned off in this demo'))
    return 'This demo workspace is not taking applications from the public careers page.'
  const missing = message.match(/missing_fields:([\w.,-]+)/)
  if (missing)
    return `Please fill in: ${missing[1]
      .split(',')
      .map((key) => key.replace(/^(template|posting)\./, '').replace(/[_-]+/g, ' '))
      .join(', ')}.`
  if (/rate|too many/i.test(message))
    return 'Too many applications from here just now. Please wait a minute and try again.'
  if (/not.found|404/i.test(message)) return 'This role is no longer open.'
  return 'We could not submit your application just now. Please try again in a moment.'
}

/** A standalone, shareable job description with an Apply button. */
export function CareersJobPage(
  handle: Handle<{ careers: CareersPage; job: CareersJob; orgQuery: string; slug: string }>,
) {
  return () => {
    let { careers, job, orgQuery, slug } = handle.props
    let apply = `${routes.careersApply.index.href({ jobId: job.id })}${orgQuery}${orgQuery ? '&' : '?'}posting_id=${encodeURIComponent(job.posting_id ?? '')}`
    let jsonLd = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'JobPosting',
      title: job.title,
      description: job.description ?? job.title,
      employmentType: job.employment_type ? job.employment_type.toUpperCase() : undefined,
      hiringOrganization: { '@type': 'Organization', name: careers.organization.name },
      jobLocation: dimension(job, 'location')
        ? { '@type': 'Place', name: dimension(job, 'location') }
        : undefined,
    }).replace(/</g, '\\u003c')
    return (
      <CandidateFrame
        title={job.title}
        orgName={careers.organization.name}
        slug={slug}
        kicker={dimension(job, 'department') ?? 'Open role'}
      >
        {jobMeta(job) ? <p class="careers-role-meta">{jobMeta(job)}</p> : null}
        {careers.careers.demo ? (
          <p class="demo-disclaimer" role="note">
            Demo job posting for an invented company. Please do not enter real personal information.
          </p>
        ) : null}
        {job.description ? (
          <DescriptionBlocks text={job.description} />
        ) : (
          <p class="sub">The team has not written a description for this role yet.</p>
        )}
        <p>
          <a class="btn btn-primary" href={apply}>
            Apply for this role
          </a>
        </p>
        <p>
          <a href={`${routes.careersIndex.href()}${orgQuery}#openings`}>← All open roles</a>
        </p>
        <script type="application/ld+json" innerHTML={unsafeHTML(jsonLd)} />
      </CandidateFrame>
    )
  }
}
