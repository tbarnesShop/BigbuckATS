import { createController } from 'remix/router'

import {
  addPeopleToPool,
  addPoolPeopleFromJob,
  addProjectMember,
  bulkMovePoolMembers,
  createProjectMemberTransition,
  getProject,
  listJobs,
  listPeople,
  listSavedSearches,
  listSequences,
  listProjectMembers,
  sessionFromEnv,
  sessionFromRequest,
  type Job,
  type SavedSearch,
  type Sequence,
} from '../../data/api.ts'
import { redirectWithNotice, takeWorkflowNotice } from '../../data/auth.ts'
import { label } from '../../data/labels.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { PoolShowPage } from './pages.tsx'

async function load(session: NonNullable<ReturnType<typeof sessionFromEnv>>, projectId: string) {
  const [project, members, people, savedSearches, jobs, sequences] = await Promise.all([
    getProject(session, projectId),
    listProjectMembers(session, { projectId }),
    // The "Add to pool" picker lists people by name; the default page of 100 hides most of a real database.
    listPeople(session, { limit: 500, sort: 'name' }),
    listSavedSearches(session).catch(() => ({ data: [] as SavedSearch[] })),
    listJobs(session).catch(() => ({ data: [] as Job[] })),
    listSequences(session).catch(() => ({ data: [] as Sequence[] })),
  ])
  return {
    project,
    members: members.data,
    people: people.data,
    savedSearches: savedSearches.data,
    jobs: jobs.data,
    sequences: sequences.data.filter((row) => row.status === 'active' && !row.is_template),
  }
}

export default createController(routes.poolsShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const data = await load(session, context.params.projectId)
        const notice = takeWorkflowNotice()
        return context.render(<PoolShowPage {...data} orgQuery={orgQuery(context.url)} notice={notice} />)
      } catch {
        return new Response('Pool not found', { status: 404 })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      try {
        let notice = 'Member added'
        const summary = (result: { added: number; already_members: number }) =>
          `Added ${result.added}${result.already_members ? `, ${result.already_members} already in the pool` : ''}.`
        if (intent === 'move_member') {
          // Sent by a drag on the board. The member must be on this pool's board and the stage one of its own.
          const memberId = String(form.get('drag_id') ?? '')
          const toStage = String(form.get('drag_to') ?? '')
          const [project, members] = await Promise.all([
            getProject(session, context.params.projectId),
            listProjectMembers(session, { projectId: context.params.projectId }),
          ])
          const member = members.data.find((row) => row.id === memberId && row.status === 'active')
          // A pool without its own pipeline shows the default sourcing stages; the API checks those keys.
          const stages = project.pipeline?.stages ?? []
          const stage = stages.find((row) => row.key === toStage)
          if (!member || !toStage || (stages.length > 0 && !stage)) {
            throw new Error('That prospect or stage is no longer on this board.')
          }
          if (member.current_stage_key !== toStage) {
            await createProjectMemberTransition(session, memberId, { command: 'move', to_stage_key: toStage })
          }
          return redirectWithNotice(
            `${routes.poolsShow.index.href({ projectId: context.params.projectId })}${orgQuery(context.url)}`,
            `Moved ${member.person?.display_name ?? 'prospect'} to ${stage?.name ?? label(toStage)}.`,
          )
        } else if (intent === 'bulk_move' || intent === 'bulk_enroll') {
          // Checked cards on the board. Only active members of this pool count, whatever the form says.
          const checked = new Set(form.getAll('member_id').map(String))
          const [project, members] = await Promise.all([
            getProject(session, context.params.projectId),
            listProjectMembers(session, { projectId: context.params.projectId }),
          ])
          const chosen = members.data.filter((row) => row.status === 'active' && checked.has(row.id))
          if (chosen.length === 0) throw new Error('Check at least one prospect on the board first.')
          const here = `${routes.poolsShow.index.href({ projectId: context.params.projectId })}${orgQuery(context.url)}`
          if (intent === 'bulk_enroll') {
            const sequenceId = String(form.get('sequence_id') ?? '')
            if (!sequenceId) throw new Error('Choose a sequence.')
            // Nothing is sent from here: the sequence page shows who would be enrolled and who is skipped, and why.
            const review = new URLSearchParams(orgQuery(context.url).replace(/^\?/, ''))
            review.set('review', chosen.map((row) => row.person_id).join(','))
            return new Response(null, {
              status: 303,
              headers: {
                Location: `${routes.sequencesShow.index.href({ sequenceId })}?${review}#enroll-review`,
              },
            })
          }
          const toStage = String(form.get('to_stage_key') ?? '')
          const stages = project.pipeline?.stages ?? []
          const stage = stages.find((row) => row.key === toStage)
          if (!toStage || (stages.length > 0 && !stage)) throw new Error('Choose a stage.')
          const moving = chosen.filter((row) => row.current_stage_key !== toStage)
          if (moving.length > 0) {
            await bulkMovePoolMembers(session, context.params.projectId, {
              member_ids: moving.map((row) => row.id),
              to_stage_key: toStage,
            })
          }
          const where = stage?.name ?? label(toStage)
          return redirectWithNotice(
            here,
            moving.length === 0
              ? `Everyone you checked is already in ${where}.`
              : `Moved ${moving.length} ${moving.length === 1 ? 'prospect' : 'prospects'} to ${where}.`,
          )
        } else if (intent === 'add_member') {
          const personId = String(form.get('person_id') ?? '').trim()
          if (!personId) throw new Error('Person is required')
          await addProjectMember(session, context.params.projectId, personId)
        } else if (intent === 'add_saved_search' || intent === 'refresh_smart') {
          const searchId = String(form.get('saved_search_id') ?? '').trim()
          // A smart pool refreshes from its own saved search when none is named.
          notice = summary(
            await addPeopleToPool(
              session,
              context.params.projectId,
              searchId ? { saved_search_id: searchId } : {},
            ),
          )
        } else if (intent === 'add_from_job') {
          const jobId = String(form.get('job_id') ?? '').trim()
          if (!jobId) throw new Error('Choose a job')
          notice = summary(await addPoolPeopleFromJob(session, context.params.projectId, jobId))
        }
        const data = await load(session, context.params.projectId)
        return context.render(<PoolShowPage {...data} orgQuery={orgQuery(context.url)} notice={notice} />)
      } catch (error) {
        try {
          const data = await load(session, context.params.projectId)
          return context.render(
            <PoolShowPage {...data} orgQuery={orgQuery(context.url)} error={String(error)} />,
          )
        } catch {
          return new Response(String(error), { status: 502 })
        }
      }
    },
  },
})
