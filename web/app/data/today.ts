import {
  listAgentProposals,
  listFollowUps,
  type AgentProposal,
  type ApiHeaders,
  type FollowUpTask,
} from './api.ts'
import { gql, GraphQLRequestError } from './graphql.ts'
import type { TodayQuery, TodayOffersQuery, TodayJobsQuery } from '../graphql/generated.ts'
import type { TodayOffer, TodayJob } from './hubs.ts'

export type TodaySection<T> = { status: 'ready'; data: T } | { status: 'omitted' | 'failed' }
export type TodayData = {
  core: TodaySection<TodayQuery>
  offers: TodaySection<TodayOffer[]>
  jobs: TodaySection<TodayJob[]>
  tasks: TodaySection<FollowUpTask[]>
  /** Agent proposals waiting for this person's decision: the newest few, and how many in all. */
  approvals: TodaySection<{ rows: AgentProposal[]; total: number }>
  canWriteFeedback: boolean
  canViewAnalytics: boolean
  canManageAgents: boolean
}

/** Keep permission omission distinct from a failed read; never substitute an empty queue. */
async function section<T>(allowed: boolean, load: () => Promise<T>): Promise<TodaySection<T>> {
  if (!allowed) return { status: 'omitted' }
  try {
    return { status: 'ready', data: await load() }
  } catch (error) {
    if (
      error instanceof GraphQLRequestError &&
      error.errors.length > 0 &&
      error.errors.every((item) => item.extensions?.code === 'insufficient_permission')
    )
      return { status: 'omitted' }
    return { status: 'failed' }
  }
}

function rows<T>(value: T[] | undefined): T[] {
  if (!Array.isArray(value)) throw new Error('Today section did not return a list')
  return value
}

export async function loadToday(
  session: ApiHeaders,
  permissions: readonly string[] | null,
): Promise<TodayData> {
  const allowed = (key: string) => permissions === null || permissions.includes(key)
  const canRead = allowed('application.read')
  const [core, offers, jobs, tasks, approvals] = await Promise.all([
    section(canRead, async () => {
      const data = await gql<TodayQuery>(session, 'Today')
      if (!data?.viewer || !data.today) throw new Error('Today did not return the daily queue')
      rows(data.today.feedback)
      rows(data.today.reviews)
      rows(data.today.upcoming)
      return data
    }),
    section(canRead && allowed('offer.read'), async () =>
      rows((await gql<TodayOffersQuery>(session, 'TodayOffers'))?.today?.offersPending),
    ),
    section(canRead && allowed('job.read'), async () =>
      rows((await gql<TodayJobsQuery>(session, 'TodayJobs'))?.today?.jobs),
    ),
    // Your open follow-ups, soonest first; the list API orders by due date.
    section(allowed('person.read'), async () =>
      rows((await listFollowUps(session, { assignee: 'me' })).data.filter((task) => task.status === 'open')),
    ),
    // Only people who can enroll decide proposals, so only they are asked to.
    section(allowed('project.read') && allowed('sequence.enroll'), async () => {
      const result = await listAgentProposals(session, { status: 'pending' })
      const list = rows(result.data)
      return { rows: list.slice(0, 4), total: result.meta?.statuses?.pending ?? list.length }
    }),
  ])
  return {
    core,
    offers,
    jobs,
    tasks,
    approvals,
    canWriteFeedback: allowed('scorecard.write'),
    canViewAnalytics: allowed('analytics.read'),
    canManageAgents: allowed('agent.manage') || allowed('agent.manage_own'),
  }
}
