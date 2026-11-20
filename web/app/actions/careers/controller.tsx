import { createController } from 'remix/router'

import { getPublicCareers, submitPublicApplication } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { careersSlugFrom, orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { notFound } from '../../ui/not-found.tsx'
import { SetupNeeded } from '../../ui/shell.tsx'
import { applyError, CareersApplyPage, submittedValues } from './pages.tsx'

export default createController(routes.careersApply, {
  actions: {
    async index(context) {
      const slug = careersSlugFrom(context.url)
      if (!slug) return context.render(<SetupNeeded />)
      try {
        const careers = await getPublicCareers(slug)
        const job = careers.jobs.find(
          (row) =>
            row.id === context.params.jobId &&
            (!context.url.searchParams.get('posting_id') ||
              row.posting_id === context.url.searchParams.get('posting_id')),
        )
        if (!job)
          return notFound(context, {
            title: 'This role is no longer open',
            message:
              'The job may have been filled or closed. Other open roles are listed on the careers page.',
            href: routes.careersIndex.href() + (context.url.search || ''),
            linkLabel: 'See open roles',
          })
        return context.render(
          <CareersApplyPage
            postingId={job.posting_id ?? undefined}
            jobId={job.id}
            jobTitle={job.title}
            orgName={careers.organization.name}
            slug={careers.organization.slug ?? slug}
            orgQuery={
              orgQuery(context.url) || `?slug=${encodeURIComponent(careers.organization.slug ?? slug)}`
            }
            questions={[
              ...((job.application_form ?? careers.application_form)?.screening_questions ?? []),
              ...((job.application_form ?? careers.application_form)?.posting_questions ?? []),
            ]}
            required={
              (job.application_form ?? careers.application_form)?.required_fields ?? ['display_name', 'email']
            }
            description={job.description}
            acceptsApplications={careers.careers.accepts_applications !== false}
            meta={[job.department, job.location, job.employment_type ? label(job.employment_type) : null]
              .filter(Boolean)
              .join(' · ')}
          />,
        )
      } catch (error) {
        return new Response(`Careers API error: ${String(error)}`, { status: 502 })
      }
    },
    async action(context) {
      const slug = careersSlugFrom(context.url)
      if (!slug) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      let careers
      try {
        careers = await getPublicCareers(slug)
      } catch (error) {
        return new Response(`Careers API error: ${String(error)}`, { status: 502 })
      }
      const job = careers.jobs.find(
        (row) =>
          row.id === context.params.jobId &&
          (!context.url.searchParams.get('posting_id') ||
            row.posting_id === context.url.searchParams.get('posting_id')),
      )
      if (!job)
        return notFound(context, {
          title: 'This role is no longer open',
          message: 'The job may have been filled or closed. Other open roles are listed on the careers page.',
          href: routes.careersIndex.href() + (context.url.search || ''),
          linkLabel: 'See open roles',
        })
      const query = orgQuery(context.url) || `?slug=${encodeURIComponent(careers.organization.slug ?? slug)}`
      const questions = [
        ...((job.application_form ?? careers.application_form)?.screening_questions ?? []),
        ...((job.application_form ?? careers.application_form)?.posting_questions ?? []),
      ]
      const required = (job.application_form ?? careers.application_form)?.required_fields ?? [
        'display_name',
        'email',
      ]
      const page = (extra: { error?: string; success?: string }) => (
        <CareersApplyPage
          postingId={job.posting_id ?? undefined}
          jobId={job.id}
          jobTitle={job.title}
          orgName={careers.organization.name}
          slug={careers.organization.slug ?? slug}
          orgQuery={query}
          questions={questions}
          required={required}
          values={submittedValues(form)}
          description={job.description}
          acceptsApplications={careers.careers.accepts_applications !== false}
          meta={[job.department, job.location, job.employment_type ? label(job.employment_type) : null]
            .filter(Boolean)
            .join(' · ')}
          error={extra.error}
          success={extra.success}
        />
      )
      if (!job.posting_id) {
        return context.render(page({ error: 'This role is not published on the careers page yet.' }))
      }
      const answers: Record<string, unknown> = {}
      for (const question of questions) {
        const value =
          question.field_type === 'multi_select'
            ? form.getAll(question.key).map(String)
            : String(form.get(question.key) ?? '').trim()
        if (value) answers[question.key] = value
      }
      const body: Record<string, unknown> = {
        display_name: String(form.get('display_name') ?? '').trim(),
        email: String(form.get('email') ?? '').trim(),
        phone: String(form.get('phone') ?? '').trim() || undefined,
        linkedin: String(form.get('linkedin') ?? '').trim() || undefined,
        links: String(form.get('links') ?? '').trim(),
        country: String(form.get('country') ?? '').trim(),
        region: String(form.get('region') ?? '').trim(),
        answers,
      }
      try {
        await submitPublicApplication(careers.organization.slug ?? slug, job.posting_id, body)
        return context.render(page({ success: 'Application submitted. A recruiter will follow up.' }))
      } catch (error) {
        console.error('Public apply failed', error)
        return context.render(page({ error: applyError(error) }))
      }
    },
  },
})
