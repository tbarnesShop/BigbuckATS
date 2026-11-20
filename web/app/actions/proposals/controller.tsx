import type { RemixNode } from 'remix/component'
import { createController } from 'remix/router'

import {
  bulkApproveProposals,
  decideAgentProposal,
  listAgentProposals,
  listJobs,
  listSequences,
  runSourcingAgent,
  sessionFromRequest,
  type AgentProposal,
  type Job,
  type Sequence,
} from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { ProposalsPage, type ProposalView } from './page.tsx'

function asView(value: unknown): ProposalView {
  return value === 'approved' || value === 'rejected' ? value : 'pending'
}

function message(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

export default createController(routes.proposals, {
  actions: {
    async index(context) {
      return render(context, asView(context.url.searchParams.get('view')))
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const view = asView(form.get('view'))
      let notice: string | undefined
      let error: string | undefined
      try {
        let intent = String(form.get('intent') ?? '')
        if (intent === 'bulk_approve') {
          let ids = form.getAll('ids').map(String)
          if (ids.length === 0) throw new Error('Select at least one person.')
          let result = await bulkApproveProposals(session, ids)
          notice = `Approved ${result.approved}${result.failed ? `, ${result.failed} could not be approved` : ''}.`
        } else if (intent.startsWith('approve:')) {
          let id = intent.slice('approve:'.length)
          let opener = String(form.get(`opener_${id}`) ?? '').trim()
          await decideAgentProposal(session, id, 'approve', opener ? { opener } : {})
          notice = 'Approved and enrolled.'
        } else if (intent.startsWith('reject:')) {
          await decideAgentProposal(session, intent.slice('reject:'.length), 'reject')
          notice = 'Rejected.'
        } else if (intent === 'run') {
          let result = await runSourcingAgent(session, String(form.get('job_id') ?? ''), {
            sequence_id: String(form.get('sequence_id') ?? ''),
            limit: Number(form.get('limit') ?? 10) || 10,
          })
          notice = `The agent proposed ${result.proposed.length} ${result.proposed.length === 1 ? 'person' : 'people'}.`
        }
      } catch (caught) {
        error = message(caught)
      }
      return render(context, view, notice, error)
    },
  },
})

async function render(
  context: { url: URL; render: (node: RemixNode) => Response | Promise<Response> },
  view: ProposalView,
  notice?: string,
  error?: string,
) {
  const session = sessionFromRequest()
  if (!session) return context.render(<SetupNeeded />)
  let permissions = signedIn()?.permissions ?? null
  let can = (key: string) => permissions === null || permissions.includes(key)
  let proposals: AgentProposal[] = []
  let counts: Record<string, number> = {}
  let jobs: Job[] = []
  let sequences: Sequence[] = []
  try {
    let result = await listAgentProposals(session, { status: view })
    proposals = result.data
    counts = result.meta?.statuses ?? {}
    if (view !== 'pending') counts = { ...(await listAgentProposals(session)).meta?.statuses, ...counts }
  } catch (caught) {
    error = error ?? message(caught)
  }
  if (can('project.manage')) {
    ;[jobs, sequences] = await Promise.all([
      listJobs(session).then((r) => r.data.filter((job) => job.status === 'open')),
      listSequences(session).then((r) => r.data),
    ]).catch(() => [[], []] as [Job[], Sequence[]])
  }
  return context.render(
    <ProposalsPage
      proposals={proposals}
      counts={counts}
      view={view}
      jobs={jobs}
      sequences={sequences}
      canDecide={can('sequence.enroll')}
      canRun={can('project.manage') && jobs.length > 0 && sequences.length > 0}
      orgQuery={orgQuery(context.url)}
      notice={notice}
      error={error}
    />,
  )
}
