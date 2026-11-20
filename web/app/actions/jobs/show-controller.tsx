import { createController } from 'remix/router'

import {
  addHiringTeamMember,
  createApplication,
  removeHiringTeamMember,
  saveJobPosting,
  updateHiringTeamMember,
  updateJobPipeline,
  type PipelineEdit,
  createApplicationTransition,
  getJob,
  getMissingFeedback,
  listProjects,
  listScorecardRubrics,
  rediscoverTalent,
  sessionFromEnv,
  sessionFromRequest,
  updateJob,
  type RediscoveryHit,
} from '../../data/api.ts'
import {
  defaultSection,
  parseBoardSection,
  parseJobTab,
  previewMove,
  sectionForStage,
  stageEnteredAt,
  stageLabel,
  jobWorkspaceHref,
} from '../../data/board.ts'
import { interviewLabel, workflowError } from '../../data/application-workflow.ts'
import { redirectWithNotice, takeWorkflowNotice } from '../../data/auth.ts'
import { gql } from '../../data/graphql.ts'
import { orgQuery } from '../../data/session.ts'
import type { JobWorkspaceQuery, JobWorkspaceQueryVariables } from '../../graphql/generated.ts'
import { routes } from '../../routes.ts'
import { notFound } from '../../ui/not-found.tsx'
import { Shell, SetupNeeded } from '../../ui/shell.tsx'
import {
  JobWorkspacePage,
  type WorkspaceApplication,
  type WorkspaceJob,
  type WorkspacePool,
} from './workspace.tsx'

const redirect = (path: string) => new Response(null, { status: 303, headers: { Location: path } })

type Session = NonNullable<ReturnType<typeof sessionFromEnv>>

async function loadWorkspace(session: Session, jobId: string) {
  const [graph, rest, rediscovery, projects] = await Promise.all([
    gql<JobWorkspaceQuery, JobWorkspaceQueryVariables>(session, 'JobWorkspace', { id: jobId }),
    getJob(session, jobId).catch(() => null),
    rediscoverTalent(session, jobId).catch(() => ({
      data: [] as RediscoveryHit[],
    })),
    listProjects(session).catch(() => ({ data: [] })),
  ])
  const rubrics = await listScorecardRubrics(session)
    .then((result) => result.data)
    .catch(() => [] as Array<{ key: string; name: string }>)
  const job = graph.job
  if (!job) return null
  const nodes = [...(job.applications.nodes ?? [])]
  let pageInfo = job.applications.pageInfo
  while (pageInfo.hasNextPage && nodes.length < 200) {
    if (!pageInfo.endCursor) throw new Error('The candidate list could not be paginated.')
    const next = await gql<JobWorkspaceQuery, JobWorkspaceQueryVariables>(session, 'JobWorkspace', {
      id: jobId,
      after: pageInfo.endCursor,
    })
    if (!next.job) throw new Error('The job could not be loaded.')
    nodes.push(...(next.job.applications.nodes ?? []))
    pageInfo = next.job.applications.pageInfo
  }
  const applications: WorkspaceApplication[] = nodes.flatMap((node) => {
    if (!node) return []
    return [
      {
        id: node.id,
        status: node.status,
        stageKey: node.currentStageKey,
        name: node.person?.displayName ?? node.person?.id ?? 'Candidate',
        email: node.person?.primaryEmail ?? null,
        enteredAt: stageEnteredAt({
          currentStageKey: node.currentStageKey,
          updatedAt: node.updatedAt,
          createdAt: node.createdAt,
          transitions: node.transitions,
        }),
        nextInterview: node.upcomingInterview?.startsAt
          ? {
              name: interviewLabel(
                node.upcomingInterview.interviewKey,
                rest?.pipeline?.stages ?? [],
                node.upcomingInterview.stageKey,
              ),
              startsAt: node.upcomingInterview.startsAt,
            }
          : null,
      },
    ]
  })
  const stageCounts: Record<string, number> = {}
  for (const app of applications) stageCounts[app.stageKey] = (stageCounts[app.stageKey] ?? 0) + 1
  const workspaceJob: WorkspaceJob = {
    id: job.id,
    title: job.title,
    status: job.status,
    openings: job.openings,
    confidential: job.confidential,
    careersVisibility: rest?.careers_visibility,
    careersPublished: rest?.careers_published,
    codeName: job.codeName,
    stages: job.stages.map((stage) => ({
      key: stage.key,
      name: stage.name,
      type: stage.type,
      interviews: rest?.pipeline?.stages.find((row) => row.key === stage.key)?.interviews ?? [],
    })),
    requisition: rest?.requisition
      ? {
          code: rest.requisition.code,
          title: rest.requisition.title,
          status: rest.requisition.status,
        }
      : null,
    dimensions: rest?.dimensions ?? [],
    hiringTeam: (rest?.hiring_team ?? []).map((member) => ({
      id: member.id,
      userId: member.user_id,
      name: member.name ?? null,
      role: member.role,
    })),
    assignableMembers: (rest?.assignable_members ?? []).map((member) => ({
      userId: member.user_id,
      name: member.name ?? member.email ?? member.user_id,
    })),
    posting: rest?.posting
      ? {
          id: rest.posting.id,
          title: rest.posting.title,
          description: rest.posting.description ?? '',
          location: rest.posting.location ?? '',
          employmentType: rest.posting.employment_type ?? '',
          version: rest.posting.version,
        }
      : null,
    stageCounts,
    rubrics: rubrics.map((row) => ({ key: row.key, name: row.name })),
  }
  const pools: WorkspacePool[] = projects.data
    .filter((project) => project.job_id === job.id)
    .map((project) => ({
      id: project.id,
      name: project.name,
      memberCount: project.member_count ?? null,
    }))
  return {
    job: workspaceJob,
    applications,
    pools,
    rediscovery: rediscovery.data,
    truncated: pageInfo.hasNextPage,
  }
}

function viewFromUrl(
  loaded: NonNullable<Awaited<ReturnType<typeof loadWorkspace>>>,
  url: URL,
  extras?: { notice?: string; error?: string },
) {
  const requested = parseBoardSection(url.searchParams.get('section'))
  return {
    ...loaded,
    orgQuery: orgQuery(url),
    tab: parseJobTab(url.searchParams.get('tab')),
    section: requested ?? defaultSection(loaded.job.stages, loaded.applications),
    selectedApplicationId: url.searchParams.get('application_id') ?? '',
    toStageKey: url.searchParams.get('to_stage_key') ?? '',
    notice:
      extras?.notice ??
      (() => {
        const moved = loaded.applications.find((app) => app.id === url.searchParams.get('moved'))
        return moved
          ? `Moved ${moved.name} to ${stageLabel(
              loaded.job.stages.find((stage) => stage.key === moved.stageKey),
              moved.stageKey,
            )}.`
          : undefined
      })(),
    error: extras?.error,
  }
}

export default createController(routes.jobsShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const loaded = await loadWorkspace(session, context.params.jobId)
        if (!loaded)
          return notFound(context, {
            title: 'Job not found',
            message: 'This job was removed, or you do not have access to it.',
            href: routes.jobsIndex.href(),
            linkLabel: 'Back to Jobs',
          })
        const notice = takeWorkflowNotice()
        const view = viewFromUrl(loaded, context.url, notice ? { notice } : undefined)
        // Only ask about owed feedback when a move preview is open; the board itself never needs it.
        const missingFeedback =
          view.tab === 'pipeline' && view.selectedApplicationId && view.toStageKey
            ? await getMissingFeedback(session, view.selectedApplicationId).catch(() => undefined)
            : undefined
        return context.render(
          <JobWorkspacePage
            {...view}
            missingFeedback={missingFeedback?.data}
            feedbackBlocks={Boolean(missingFeedback?.blocking)}
          />,
        )
      } catch (error) {
        console.error('Could not load job workspace', error)
        return context.render(
          <Shell title="Could not load this job" orgQuery={orgQuery(context.url)}>
            <p role="alert">The job workspace could not be loaded. Please try again.</p>
            <a href={context.url.pathname + context.url.search}>Try again</a>
            <p>
              <a href={routes.jobsIndex.href()}>Back to jobs</a>
            </p>
          </Shell>,
          { status: 502 },
        )
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      const applicationId = String(form.get('application_id') ?? '')
      const toStageKey = String(form.get('to_stage_key') ?? '')
      const reason = String(form.get('reason') ?? '').trim()
      try {
        const loaded = await loadWorkspace(session, context.params.jobId)
        if (!loaded)
          return notFound(context, {
            title: 'Job not found',
            message: 'This job was removed, or you do not have access to it.',
            href: routes.jobsIndex.href(),
            linkLabel: 'Back to Jobs',
          })
        if (intent === 'convert') {
          const personId = String(form.get('person_id') ?? '').trim()
          if (!personId) throw new Error('Choose a person')
          await createApplication(session, {
            job_id: context.params.jobId,
            person_id: personId,
          })
          const fresh = (await loadWorkspace(session, context.params.jobId)) ?? loaded
          const url = new URL(context.url)
          url.searchParams.set('tab', 'sourcing')
          return context.render(
            <JobWorkspacePage {...viewFromUrl(fresh, url, { notice: 'Added to this job.' })} />,
          )
        }
        if (intent === 'careers') {
          const visibility = String(form.get('careers_visibility'))
          if (!['public', 'internal', 'both', 'hidden'].includes(visibility))
            throw new Error('Choose a careers audience')
          await updateJob(session, context.params.jobId, {
            careers_visibility: visibility as import('../../data/api.ts').CareersVisibility,
            careers_published: form.get('careers_published') === 'true',
          })
          const fresh = (await loadWorkspace(session, context.params.jobId)) ?? loaded
          const url = new URL(context.url)
          url.searchParams.set('tab', 'settings')
          return context.render(
            <JobWorkspacePage
              {...viewFromUrl(fresh, url, {
                notice: 'Careers settings saved.',
              })}
            />,
          )
        }
        if (intent === 'team_add') {
          const userId = String(form.get('user_id') ?? '')
          const role = String(form.get('team_role') ?? '')
          if (!userId) throw new Error('Choose a person for the hiring team')
          if (!['hiring-manager', 'recruiter', 'coordinator', 'interviewer'].includes(role))
            throw new Error('Choose a team role')
          await addHiringTeamMember(session, context.params.jobId, {
            user_id: userId,
            team_role: role as import('../../data/api.ts').HiringTeamRole,
          })
          return redirectWithNotice(
            `${jobWorkspaceHref(context.params.jobId, orgQuery(context.url), { tab: 'settings' })}#hiring-team`,
            'Added to the hiring team.',
          )
        }
        // Saved settings redirect back to their section so a refresh cannot repeat the write.
        const settingsView = (notice: string, anchor = '') =>
          redirectWithNotice(
            `${jobWorkspaceHref(context.params.jobId, orgQuery(context.url), { tab: 'settings' })}${anchor}`,
            notice,
          )
        if (intent === 'team_role') {
          const role = String(form.get('team_role') ?? '')
          if (!['hiring-manager', 'recruiter', 'coordinator', 'interviewer'].includes(role))
            throw new Error('Choose a team role')
          await updateHiringTeamMember(
            session,
            context.params.jobId,
            String(form.get('member_id') ?? ''),
            role as import('../../data/api.ts').HiringTeamRole,
          )
          return settingsView('Hiring team role changed.', '#hiring-team')
        }
        if (intent === 'team_remove') {
          const memberId = String(form.get('member_id') ?? '')
          const member = loaded.job.hiringTeam.find((row) => row.id === memberId)
          await removeHiringTeamMember(session, context.params.jobId, memberId)
          return settingsView(
            `${member?.name ?? 'Team member'} removed from the hiring team.`,
            '#hiring-team',
          )
        }
        if (intent === 'pipeline') {
          const op = String(form.get('op') ?? '')
          const key = String(form.get('key') ?? '')
          const name = String(form.get('name') ?? '').trim()
          let edit: PipelineEdit
          if (op === 'add_stage') edit = { op, name, type: String(form.get('type') ?? 'interview') }
          else if (op === 'rename_stage') edit = { op, key, name }
          else if (op === 'move_stage')
            edit = { op, key, direction: form.get('direction') === 'up' ? 'up' : 'down' }
          else if (op === 'remove_stage') edit = { op, key }
          else if (op === 'add_interview') {
            const minutes = Number(form.get('duration_minutes') ?? 0)
            const rubric = String(form.get('rubric_key') ?? '')
            edit = {
              op,
              key,
              name,
              required: form.get('required') !== 'false',
              ...(rubric ? { rubric_key: rubric } : {}),
              ...(minutes > 0 ? { duration_minutes: minutes } : {}),
            }
          } else if (op === 'remove_interview')
            edit = { op, key, interview_key: String(form.get('interview_key') ?? '') }
          else throw new Error('Unknown pipeline change')
          if ((op === 'add_stage' || op === 'rename_stage' || op === 'add_interview') && !name)
            throw new Error(op === 'add_interview' ? 'Give the interview a name' : 'Give the stage a name')
          await updateJobPipeline(session, context.params.jobId, edit)
          const stage = stageLabel(
            loaded.job.stages.find((row) => row.key === key),
            key,
          )
          const notices: Record<string, string> = {
            add_stage: `Added ${name}.`,
            rename_stage: `Renamed ${stage} to ${name}.`,
            move_stage: `Moved ${stage}.`,
            remove_stage: `Removed ${stage}.`,
            add_interview: `Added ${name} to ${stage}.`,
            remove_interview: `Removed an interview from ${stage}.`,
          }
          return settingsView(
            notices[op] ?? 'Pipeline saved.',
            op.endsWith('interview') ? '#interview-plan' : '#pipeline',
          )
        }
        if (intent === 'posting_details') {
          const postingId = String(form.get('posting_id') ?? '')
          if (!postingId || postingId !== loaded.job.posting?.id)
            throw new Error('This job has no posting to edit')
          const title = String(form.get('title') ?? '').trim()
          if (!title) throw new Error('Give the posting a title')
          await saveJobPosting(session, context.params.jobId, postingId, {
            title,
            description: String(form.get('description') ?? '').trim(),
            location: String(form.get('location') ?? '').trim(),
            employment_type: String(form.get('employment_type') ?? '') || null,
            expected_version: Number(form.get('expected_version')),
          })
          return settingsView('Job posting saved.', '#job-posting')
        }
        if (intent === 'openings') {
          const openings = Number(form.get('openings'))
          if (!Number.isFinite(openings) || openings < 0) throw new Error('Openings must be zero or more')
          await updateJob(session, context.params.jobId, { openings })
          const fresh = (await loadWorkspace(session, context.params.jobId)) ?? loaded
          const url = new URL(context.url)
          url.searchParams.set('tab', 'settings')
          return context.render(
            <JobWorkspacePage
              {...viewFromUrl(fresh, url, {
                notice: `Openings set to ${openings}.`,
              })}
            />,
          )
        }
        if (intent !== 'move') {
          return context.render(
            <JobWorkspacePage
              {...viewFromUrl(loaded, context.url, {
                error: 'Nothing to save on this job.',
              })}
            />,
          )
        }
        const preview = previewMove({
          applicationId,
          toStageKey,
          applications: loaded.applications,
          stages: loaded.job.stages,
        })
        if (!preview || !preview.ok) {
          const url = new URL(context.url)
          url.searchParams.set('tab', 'pipeline')
          url.searchParams.set('application_id', applicationId)
          url.searchParams.set('to_stage_key', toStageKey)
          const section = String(form.get('section') ?? '')
          if (section) url.searchParams.set('section', section)
          return context.render(
            <JobWorkspacePage
              {...viewFromUrl(loaded, url, {
                error: preview && !preview.ok ? preview.message : 'Choose a candidate and a stage.',
              })}
            />,
          )
        }
        await createApplicationTransition(session, applicationId, {
          command: 'move',
          to_stage_key: toStageKey,
          ...(reason ? { reason } : {}),
        })
        const fresh = (await loadWorkspace(session, context.params.jobId)) ?? loaded
        const destination = fresh.job.stages.find((stage) => stage.key === toStageKey)
        return redirect(
          jobWorkspaceHref(context.params.jobId, orgQuery(context.url), {
            tab: 'pipeline',
            section: sectionForStage(destination ?? { key: toStageKey }),
            moved: applicationId,
          }),
        )
      } catch (error) {
        const message = workflowError(error).replace(
          'See the interview plan below.',
          'Open the candidate to complete their interview plan.',
        )
        try {
          const loaded = await loadWorkspace(session, context.params.jobId)
          if (!loaded)
            return notFound(context, {
              title: 'Job not found',
              message: 'This job was removed, or you do not have access to it.',
              href: routes.jobsIndex.href(),
              linkLabel: 'Back to Jobs',
            })
          const url = new URL(context.url)
          if (
            [
              'careers',
              'team_add',
              'team_role',
              'team_remove',
              'pipeline',
              'posting_details',
              'openings',
            ].includes(intent)
          ) {
            url.searchParams.set('tab', 'settings')
          }
          return context.render(
            <JobWorkspacePage
              {...viewFromUrl(loaded, url, {
                error: `Could not save: ${message}`,
              })}
            />,
          )
        } catch {
          return notFound(context, {
            title: 'Job not found',
            message: 'This job was removed, or you do not have access to it.',
            href: routes.jobsIndex.href(),
            linkLabel: 'Back to Jobs',
          })
        }
      }
    },
  },
})
