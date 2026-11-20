import { labStatusController, labInspectController } from './lab/controller.tsx'
import { docsIndexController, docsController, docsReferenceController } from './docs/controller.tsx'
import { createController } from 'remix/router'

import { personDocument } from './people/document-controller.ts'
import { serveAsset } from '../assets.ts'
import {
  getPersonTimeline,
  getPublicCareers,
  getPublicScheduling,
  getTeam,
  listApplications,
  getApplication,
  getInterview,
  getJob,
  listScorecardRubrics,
  listScorecards,
  listAwaitingSchedule,
  listCompanies,
  listJobs,
  listMailboxes,
  listPeople,
  listProjects,
  listSavedSearches,
  listSequences,
  getFunnelAnalytics,
  getSourcingAnalytics,
  getOutreachFunnel,
  type Sequence,
  sessionFromEnv,
  sessionFromRequest,
} from '../data/api.ts'
import { signedIn, takeWorkflowNotice } from '../data/auth.ts'
import { commandList, filterCommands, visibleCommands } from '../data/commands.ts'
import { gql } from '../data/graphql.ts'
import { interviewScope, offerCounts, offerTabById, selectOfferTab } from '../data/hubs.ts'
import { loadToday } from '../data/today.ts'
import { careersSlugFrom, orgQuery } from '../data/session.ts'
import type { InterviewsHubQuery, OffersHubQuery } from '../graphql/generated.ts'
import { routes } from '../routes.ts'
import { notFound } from '../ui/not-found.tsx'
import { SetupNeeded } from '../ui/shell.tsx'
import { internalCareersController } from './careers/internal-controller.tsx'
import { CareersIndexPage, CareersJobPage } from './careers/pages.tsx'
import { ApplicationsIndexPage } from './applications/index-page.tsx'
import { CompaniesIndexPage } from './companies/pages.tsx'
import { HomePage } from './home-page.tsx'
import { SearchPage } from './search-page.tsx'
import { InterviewsHubPage } from './interviews/page.tsx'
import { InterviewDetailPage } from './interviews/detail.tsx'
import { OffersHubPage } from './offers/pages.tsx'
import { JobsIndexPage } from './jobs/pages.tsx'
import { PeopleIndexPage } from './people/pages.tsx'
import { PersonTimelineFrame } from './people/timeline-frame.tsx'
import { PoolsIndexPage } from './pools/pages.tsx'
import { SequencesIndexPage } from './sequences/pages.tsx'
import { AnalyticsPage } from './analytics/pages.tsx'
import { SchedulingPublicPage } from './scheduling/page.tsx'
import { SettingsIndexPage } from './settings/pages.tsx'
import { TodayPage } from './today/page.tsx'
import { TeamPage } from './settings/team.tsx'
import { peopleFormAction } from './people/controller.tsx'

export default createController(routes, {
  actions: {
    personDocument(context) {
      return personDocument(context, context.params.personId, context.params.documentId)
    },
    labStatus: labStatusController.actions.labStatus,
    labInspect: labInspectController.actions.labInspect,
    docsIndex: docsIndexController.actions.docsIndex,
    docsPage: docsController.actions.docsPage,
    docsReference: docsReferenceController.actions.docsReference,
    async assets(context) {
      return (await serveAsset(context.request)) ?? new Response('Not Found', { status: 404 })
    },
    async home(context) {
      if (signedIn()) return context.render(<HomePage orgQuery={orgQuery(context.url)} />)
      return new Response(null, { status: 303, headers: { Location: `/session${context.url.search}` } })
    },
    async search(context) {
      const query = context.url.searchParams.get('q') ?? ''
      const commands = filterCommands(visibleCommands(commandList(orgQuery(context.url))), query)
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      let people: { id: string; display_name: string }[] = []
      let jobs: { id: string; title: string }[] = []
      const permissions = signedIn()?.permissions ?? []
      let peopleState: 'ready' | 'failed' | 'omitted' = permissions.includes('person.read')
        ? 'ready'
        : 'omitted'
      let jobsState: 'ready' | 'failed' | 'omitted' = permissions.includes('job.read') ? 'ready' : 'omitted'
      if (session && query.trim()) {
        const [foundPeople, foundJobs] = await Promise.allSettled([
          peopleState === 'ready' ? listPeople(session, { q: query }) : Promise.resolve({ data: [] }),
          jobsState === 'ready' ? listJobs(session) : Promise.resolve({ data: [] }),
        ])
        if (foundPeople.status === 'fulfilled') people = foundPeople.value.data.slice(0, 8)
        else peopleState = 'failed'
        if (foundJobs.status === 'fulfilled') {
          const needle = query.trim().toLowerCase()
          jobs = foundJobs.value.data.filter((job) => job.title.toLowerCase().includes(needle)).slice(0, 8)
        } else jobsState = 'failed'
      }
      return context.render(
        <SearchPage
          query={query}
          peopleState={peopleState}
          jobsState={jobsState}
          commands={commands}
          people={people}
          jobs={jobs}
          orgQuery={orgQuery(context.url)}
        />,
      )
    },
    peopleList: peopleFormAction,
    async peopleIndex(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const q = context.url.searchParams.get('q') ?? ''
        const lifecycle = context.url.searchParams.get('lifecycle_stage') ?? ''
        const projectId = context.url.searchParams.get('project_id') ?? ''
        const advanced = {
          tag: context.url.searchParams.get('tag') ?? '',
          source: context.url.searchParams.get('source') ?? '',
          engagement_status: context.url.searchParams.get('engagement_status') ?? '',
          location: context.url.searchParams.get('location') ?? '',
          not_contacted_days: context.url.searchParams.get('not_contacted_days') ?? '',
        }
        const page = Math.max(1, Number(context.url.searchParams.get('page') ?? '1') || 1)
        const [people, sequences, projects, saved] = await Promise.all([
          listPeople(session, {
            q: q || undefined,
            lifecycle_stage: lifecycle || undefined,
            project_id: projectId || undefined,
            ...Object.fromEntries(Object.entries(advanced).map(([k, v]) => [k, v || undefined])),
            page,
            limit: 50,
          }),
          listSequences(session).catch(() => ({ data: [] })),
          listProjects(session).catch(() => ({ data: [] })),
          listSavedSearches(session).catch(() => ({ data: [] })),
        ])
        return context.render(
          <PeopleIndexPage
            people={people.data}
            sequences={sequences.data}
            projects={projects.data}
            savedSearches={saved.data}
            filters={{ q, lifecycle_stage: lifecycle, project_id: projectId, ...advanced }}
            orgQuery={orgQuery(context.url)}
            notice={takeWorkflowNotice()}
            page={people.meta?.page ?? page}
            total={people.meta?.total}
            perPage={people.meta?.per_page ?? 50}
          />,
        )
      } catch (error) {
        return new Response(`People API error: ${String(error)}`, { status: 502 })
      }
    },
    async applicationsIndex(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const jobId = context.url.searchParams.get('job_id') ?? ''
        const stage = context.url.searchParams.get('stage') ?? ''
        const requested = context.url.searchParams.get('status') ?? 'active'
        const view =
          (['active', 'hired', 'archived', 'all'] as const).find((value) => value === requested) ?? 'active'
        const page = Math.max(1, Number(context.url.searchParams.get('page') ?? '1') || 1)
        const [listed, jobs] = await Promise.all([
          listApplications(session, {
            jobId: jobId || undefined,
            stage: stage || undefined,
            status: view === 'all' ? undefined : view,
            sort: 'mine',
            page,
            perPage: 25,
          }),
          listJobs(session).catch(() => ({ data: [] })),
        ])
        // Stage filter options: one entry per key, labelled with its name (jobs may name a key differently).
        const stageNames = new Map<string, string>()
        for (const item of jobs.data.flatMap((job) => job.pipeline?.stages ?? [])) {
          if (item.key && !stageNames.has(item.key)) stageNames.set(item.key, item.name || item.key)
        }
        const stages = [...stageNames].map(([key, name]) => ({ key, name }))
        return context.render(
          <ApplicationsIndexPage
            applications={listed.data}
            jobs={jobs.data}
            stages={stages}
            orgQuery={orgQuery(context.url)}
            jobId={jobId}
            stage={stage}
            view={view}
            page={listed.meta?.page ?? page}
            total={listed.meta?.total ?? listed.data.length}
            perPage={listed.meta?.per_page ?? 25}
          />,
        )
      } catch (error) {
        return new Response(`Applications API error: ${String(error)}`, { status: 502 })
      }
    },
    async companiesIndex(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listCompanies(session)
        return context.render(<CompaniesIndexPage companies={data} orgQuery={orgQuery(context.url)} />)
      } catch (error) {
        return new Response(`Companies API error: ${String(error)}`, { status: 502 })
      }
    },
    async jobsIndex(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const { data } = await listJobs(session)
        // "open" is how people say active.
        const requested = (context.url.searchParams.get('status') ?? '').toLowerCase()
        const status = requested === 'open' ? 'active' : requested
        return context.render(
          <JobsIndexPage
            jobs={data}
            status={['draft', 'active', 'paused', 'closed', 'archived'].includes(status) ? status : ''}
            orgQuery={orgQuery(context.url)}
            notice={takeWorkflowNotice()}
          />,
        )
      } catch (error) {
        return new Response(`Jobs API error: ${String(error)}`, { status: 502 })
      }
    },
    async careersJob(context) {
      const slug = careersSlugFrom(context.url)
      if (!slug) return context.render(<SetupNeeded />)
      try {
        const careers = await getPublicCareers(slug)
        const postingId = context.url.searchParams.get('posting_id')
        const job = careers.jobs.find(
          (row) => row.id === context.params.jobId && (!postingId || row.posting_id === postingId),
        )
        if (!job)
          return notFound(context, {
            title: 'This role is no longer open',
            message:
              'The job may have been filled or closed. Other open roles are listed on the careers page.',
            href: routes.careersIndex.href() + (context.url.search || ''),
            linkLabel: 'See open roles',
          })
        const query =
          orgQuery(context.url) || `?slug=${encodeURIComponent(careers.organization.slug ?? slug)}`
        return context.render(
          <CareersJobPage
            careers={careers}
            job={job}
            orgQuery={query}
            slug={careers.organization.slug ?? slug}
          />,
        )
      } catch (error) {
        return new Response(`Careers API error: ${String(error)}`, { status: 502 })
      }
    },
    async careersSitemap(context) {
      const slug = careersSlugFrom(context.url)
      if (!slug) return new Response('Not found', { status: 404 })
      try {
        const careers = await getPublicCareers(slug)
        const origin = context.url.origin
        const query = `?slug=${encodeURIComponent(careers.organization.slug ?? slug)}`
        const urls = [
          `${origin}${routes.careersIndex.href()}${query}`,
          ...careers.jobs
            .filter((job) => job.status === 'active')
            .map(
              (job) =>
                `${origin}${routes.careersJob.href({ jobId: job.id })}${query}&posting_id=${encodeURIComponent(job.posting_id ?? '')}`,
            ),
        ]
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls
          .map((loc) => `  <url><loc>${loc.replace(/&/g, '&amp;')}</loc></url>`)
          .join('\n')}\n</urlset>\n`
        return new Response(xml, { headers: { 'Content-Type': 'application/xml; charset=utf-8' } })
      } catch {
        return new Response('Not found', { status: 404 })
      }
    },
    async today(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const data = await loadToday(session, signedIn()?.permissions ?? null)
      return context.render(
        <TodayPage
          data={data}
          kind={context.url.searchParams.get('kind')}
          orgQuery={orgQuery(context.url)}
        />,
      )
    },
    async settingsTeam(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const team = await getTeam(session)
        return context.render(<TeamPage members={team.data} roles={team.roles} />)
      } catch {
        return new Response('The team list is not available for your role.', { status: 403 })
      }
    },
    async interviewsIndex(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const scopeParam = interviewScope(context.url.searchParams.get('scope'))
        const [data, awaiting] = await Promise.all([
          gql<InterviewsHubQuery, { scope: string }>(session, 'InterviewsHub', { scope: scopeParam }),
          listAwaitingSchedule(session, scopeParam).catch(() => ({ data: [] })),
        ])
        return context.render(
          <InterviewsHubPage
            awaiting={awaiting.data}
            userId={data.viewer.user?.id ?? null}
            lists={{
              upcoming: data.upcoming,
              schedule: data.schedule,
              feedback: data.feedback,
              mine: data.mine,
            }}
            tab={context.url.searchParams.get('tab')}
            scope={context.url.searchParams.get('scope')}
            orgQuery={orgQuery(context.url)}
          />,
        )
      } catch (error) {
        return new Response(`Interviews could not load: ${String(error)}`, { status: 502 })
      }
    },
    async interviewsShow(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const back = {
        href: routes.interviewsIndex.href(),
        linkLabel: 'Back to Interviews',
      }
      let interview: Awaited<ReturnType<typeof getInterview>>
      try {
        interview = await getInterview(session, context.params.interviewId)
      } catch {
        return notFound(context, {
          title: 'Interview not found',
          message: 'This interview was removed, or the link is out of date.',
          ...back,
        })
      }
      const query = orgQuery(context.url)
      let application: Awaited<ReturnType<typeof getApplication>>
      try {
        application = await getApplication(session, interview.application_id)
      } catch {
        return notFound(context, {
          title: 'Application not found',
          message: 'This interview belongs to an application that is no longer in this workspace.',
          ...back,
        })
      }
      const [scorecards, rubrics, job] = await Promise.all([
        listScorecards(session, { applicationId: application.id }).catch(() => ({ data: [] })),
        listScorecardRubrics(session).catch(() => ({ data: [] })),
        getJob(session, application.job_id).catch(() => null),
      ])
      return context.render(
        <InterviewDetailPage
          interview={interview}
          application={application}
          scorecards={scorecards.data}
          rubrics={rubrics.data}
          hiringTeam={(job?.hiring_team ?? []).map((member) => ({
            userId: member.user_id,
            name: member.name ?? member.user_id,
          }))}
          orgQuery={query}
          notice={takeWorkflowNotice()}
        />,
      )
    },
    async offersIndex(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const query = context.url.searchParams.get('tab')
        const listed = await gql<OffersHubQuery, { status?: string | null }>(session, 'OffersHub')
        const counts = offerCounts(listed.offers.counts)
        const tab = selectOfferTab(query, counts)
        const status = offerTabById(tab).status
        let nodes = listed.offers.nodes.filter((row) => row.status === status)
        if (nodes.length < (counts[status] ?? 0)) {
          const filtered = await gql<OffersHubQuery, { status?: string | null }>(session, 'OffersHub', {
            status,
          })
          nodes = filtered.offers.nodes
        }
        return context.render(
          <OffersHubPage tab={tab} counts={counts} offers={nodes} orgQuery={orgQuery(context.url)} />,
        )
      } catch (error) {
        return new Response(`Offers could not load: ${String(error)}`, { status: 502 })
      }
    },
    async settingsIndex(context) {
      const current = signedIn()
      if (!current) return context.render(<SetupNeeded />)
      return context.render(<SettingsIndexPage />)
    },
    async poolsIndex(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const [{ data: projects }, { data: jobs }] = await Promise.all([
          listProjects(session),
          listJobs(session),
        ])
        return context.render(
          <PoolsIndexPage projects={projects} jobs={jobs} orgQuery={orgQuery(context.url)} />,
        )
      } catch (error) {
        return new Response(`Pools API error: ${String(error)}`, { status: 502 })
      }
    },
    async sequencesIndex(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const [sequences, people, mailboxes] = await Promise.all([
          listSequences(session),
          listPeople(session),
          listMailboxes(session),
        ])
        return context.render(
          <SequencesIndexPage
            sequences={sequences.data}
            people={people.data}
            mailboxes={mailboxes.data}
            orgQuery={orgQuery(context.url)}
          />,
        )
      } catch (error) {
        return new Response(`Sequences API error: ${String(error)}`, { status: 502 })
      }
    },
    async analytics(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const [funnel, sourcing, outreach, sequences] = await Promise.all([
          getFunnelAnalytics(session),
          getSourcingAnalytics(session),
          // Outreach results need sourcing access too; the page still shows the rest without them.
          getOutreachFunnel(session).catch(() => null),
          listSequences(session).catch(() => ({ data: [] as Sequence[] })),
        ])
        const running = sequences.data.filter((row) => !row.is_template).slice(0, 12)
        const perSequence = outreach
          ? (
              await Promise.all(
                running.map(async (sequence) => {
                  const result = await getOutreachFunnel(session, sequence.id).catch(() => null)
                  return result ? { sequence, result } : null
                }),
              )
            ).filter((row) => row !== null)
          : []
        return context.render(
          <AnalyticsPage
            funnel={funnel}
            sourcing={sourcing}
            outreach={outreach}
            perSequence={perSequence}
            orgQuery={orgQuery(context.url)}
          />,
        )
      } catch (error) {
        return new Response(`Analytics API error: ${String(error)}`, { status: 502 })
      }
    },
    internalCareers: internalCareersController.actions.internalCareers,
    async careersIndex(context) {
      const slug = careersSlugFrom(context.url)
      if (!slug) return context.render(<SetupNeeded />)
      try {
        const careers = await getPublicCareers(slug)
        const query = `?${new URLSearchParams({ slug: careers.organization.slug ?? slug })}`
        return context.render(
          <CareersIndexPage
            careers={careers}
            orgQuery={query}
            department={context.url.searchParams.get('department') ?? ''}
            location={context.url.searchParams.get('location') ?? ''}
          />,
        )
      } catch (error) {
        return new Response(`Careers API error: ${String(error)}`, { status: 502 })
      }
    },
    async peopleTimeline(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return new Response('Unauthorized', { status: 401 })
      try {
        const { data } = await getPersonTimeline(session, context.params.personId)
        return context.render(<PersonTimelineFrame events={data} />)
      } catch {
        return new Response('Not found', { status: 404 })
      }
    },
    async schedulingPublic(context) {
      try {
        const link = await getPublicScheduling(context.params.token)
        return context.render(<SchedulingPublicPage link={link} token={context.params.token} />)
      } catch {
        const response = await context.render(
          <SchedulingPublicPage token={context.params.token} link={{ usable: false, kind: 'unavailable' }} />,
        )
        return new Response(response.body, { status: 404, headers: response.headers })
      }
    },
  },
})
