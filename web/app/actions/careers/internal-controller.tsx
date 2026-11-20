import { createController } from 'remix/router'
import { getInternalCareers, submitInternalApplication, sessionFromRequest } from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { routes } from '../../routes.ts'
import { notFound } from '../../ui/not-found.tsx'
import { CareersApplyPage, CareersIndexPage, submittedValues } from './pages.tsx'
import { label } from '../../data/labels.ts'

const privateHeaders = { 'Cache-Control': 'private, no-store', 'X-Robots-Tag': 'noindex, nofollow' }
function privateResponse(response: Response) {
  for (const [key, value] of Object.entries(privateHeaders)) response.headers.set(key, value)
  return response
}
function signInRequired() {
  return new Response(null, {
    status: 303,
    headers: { ...privateHeaders, Location: routes.login.index.href() },
  })
}

export const internalCareersController = createController(
  { internalCareers: routes.internalCareers },
  {
    actions: {
      async internalCareers(context) {
        const session = sessionFromRequest()
        if (!session) return signInRequired()
        try {
          const careers = await getInternalCareers(session)
          return privateResponse(
            await context.render(
              <CareersIndexPage
                careers={careers}
                internal
                orgQuery={`?slug=${encodeURIComponent(careers.organization.slug)}`}
                department={context.url.searchParams.get('department') ?? ''}
                location={context.url.searchParams.get('location') ?? ''}
              />,
            ),
          )
        } catch {
          return new Response(
            'Internal careers unavailable. Sign in with an active organization membership.',
            { status: 403, headers: privateHeaders },
          )
        }
      },
    },
  },
)

export const internalApplyController = createController(routes.internalCareersApply, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return signInRequired()
      try {
        const careers = await getInternalCareers(session)
        const job = careers.jobs.find(
          (row) =>
            row.id === context.params.jobId &&
            (!context.url.searchParams.get('posting_id') ||
              row.posting_id === context.url.searchParams.get('posting_id')),
        )
        if (!job)
          return notFound(
            context,
            {
              title: 'This role is no longer open',
              message: 'The job may have been filled or closed.',
              href: routes.internalCareers.href(),
              linkLabel: 'See internal roles',
            },
            { headers: privateHeaders },
          )
        return privateResponse(
          await context.render(
            <CareersApplyPage
              internal
              postingId={job.posting_id ?? undefined}
              jobId={job.id}
              jobTitle={job.title}
              orgName={careers.organization.name}
              slug={careers.organization.slug}
              orgQuery=""
              employeeName={signedIn()?.name}
              employeeEmail={signedIn()?.email}
              questions={[
                ...((job.application_form ?? careers.application_form)?.screening_questions ?? []),
                ...((job.application_form ?? careers.application_form)?.posting_questions ?? []),
              ]}
              required={
                (job.application_form ?? careers.application_form)?.required_fields ?? [
                  'display_name',
                  'email',
                ]
              }
              description={job.description}
              meta={[job.department, job.location, job.employment_type ? label(job.employment_type) : null]
                .filter(Boolean)
                .join(' · ')}
            />,
          ),
        )
      } catch {
        return new Response('Internal careers unavailable. Sign in with an active organization membership.', {
          status: 403,
          headers: privateHeaders,
        })
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return signInRequired()
      try {
        const careers = await getInternalCareers(session)
        const job = careers.jobs.find(
          (row) =>
            row.id === context.params.jobId &&
            (!context.url.searchParams.get('posting_id') ||
              row.posting_id === context.url.searchParams.get('posting_id')),
        )
        if (!job?.posting_id)
          return notFound(
            context,
            {
              title: 'This role is no longer open',
              message: 'The job may have been filled or closed.',
              href: routes.internalCareers.href(),
              linkLabel: 'See internal roles',
            },
            { headers: privateHeaders },
          )
        const form = await context.request.formData()
        const answers = Object.fromEntries(
          [
            ...((job.application_form ?? careers.application_form)?.screening_questions ?? []),
            ...((job.application_form ?? careers.application_form)?.posting_questions ?? []),
          ].map((q) => [
            q.key,
            q.field_type === 'multi_select'
              ? form.getAll(q.key).map(String)
              : String(form.get(q.key) ?? '').trim(),
          ]),
        )
        let error: string | undefined
        let success: string | undefined
        try {
          await submitInternalApplication(session, job.posting_id, {
            phone: String(form.get('phone') ?? '').trim(),
            linkedin: String(form.get('linkedin') ?? '').trim(),
            links: String(form.get('links') ?? '').trim(),
            country: String(form.get('country') ?? '').trim(),
            region: String(form.get('region') ?? '').trim(),
            answers,
          })
          success = 'Application submitted. A recruiter will follow up.'
        } catch {
          error = 'Could not apply. Check required fields and try again.'
        }
        return privateResponse(
          await context.render(
            <CareersApplyPage
              internal
              postingId={job.posting_id ?? undefined}
              jobId={job.id}
              jobTitle={job.title}
              orgName={careers.organization.name}
              slug={careers.organization.slug}
              orgQuery=""
              employeeName={signedIn()?.name}
              employeeEmail={signedIn()?.email}
              questions={[
                ...((job.application_form ?? careers.application_form)?.screening_questions ?? []),
                ...((job.application_form ?? careers.application_form)?.posting_questions ?? []),
              ]}
              required={
                (job.application_form ?? careers.application_form)?.required_fields ?? [
                  'display_name',
                  'email',
                ]
              }
              values={submittedValues(form)}
              error={error}
              success={success}
              description={job.description}
              meta={[job.department, job.location, job.employment_type ? label(job.employment_type) : null]
                .filter(Boolean)
                .join(' · ')}
            />,
          ),
        )
      } catch {
        return new Response('Internal careers unavailable. Sign in with an active organization membership.', {
          status: 403,
          headers: privateHeaders,
        })
      }
    },
  },
})
