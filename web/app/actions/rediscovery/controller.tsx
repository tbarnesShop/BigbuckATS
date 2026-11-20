import type { RemixNode } from 'remix/component'
import { createController } from 'remix/router'

import {
  getJob,
  getRediscoveryCriteria,
  listRediscoveryQueue,
  listSequences,
  reviewRediscoveryCandidate,
  runRediscovery,
  saveRediscoveryCriteria,
  sessionFromRequest,
  type RediscoveryCandidate,
  type RediscoveryCriterion,
  type Sequence,
} from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { RediscoveryPage } from './page.tsx'

function message(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

export default createController(routes.jobRediscovery, {
  actions: {
    async index(context) {
      return render(context, context.params.jobId, context.url.searchParams.get('bucket') ?? '')
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const jobId = context.params.jobId
      const form = await context.request.formData()
      const bucket = String(form.get('bucket') ?? '')
      let notice: string | undefined
      let error: string | undefined
      try {
        let intent = String(form.get('intent') ?? '')
        if (intent === 'add_criterion' || intent === 'remove_criterion') {
          let current = (await getRediscoveryCriteria(session, jobId)).criteria
          let next: RediscoveryCriterion[] = current
          if (intent === 'add_criterion') {
            next = [
              ...current,
              {
                id: '',
                label: String(form.get('label') ?? '').trim(),
                kind: form.get('kind') === 'nice' ? 'nice' : 'must',
                match: {
                  [String(form.get('match_key') ?? 'q')]: String(form.get('match_value') ?? '').trim(),
                },
              },
            ]
          } else {
            next = current.filter((criterion) => criterion.id !== String(form.get('remove_id') ?? ''))
          }
          await saveRediscoveryCriteria(
            session,
            jobId,
            next.map((criterion) => ({ ...criterion, id: criterion.id || undefined })),
          )
          notice = intent === 'add_criterion' ? 'Criterion added.' : 'Criterion removed.'
        } else if (intent === 'run') {
          let result = await runRediscovery(session, jobId)
          notice = `Found ${result.created} new and refreshed ${result.refreshed}.`
        } else if (intent.startsWith('review:')) {
          let [, id = '', reviewAction = ''] = intent.split(':')
          let sequenceId = String(form.get('sequence_id') ?? '')
          await reviewRediscoveryCandidate(session, id, {
            review_action: reviewAction,
            ...(reviewAction === 'enroll' && sequenceId ? { sequence_id: sequenceId } : {}),
          })
          notice = 'Saved.'
        }
      } catch (caught) {
        error = message(caught)
      }
      return render(context, jobId, bucket, notice, error)
    },
  },
})

async function render(
  context: { url: URL; render: (node: RemixNode) => Response | Promise<Response> },
  jobId: string,
  bucket: string,
  notice?: string,
  error?: string,
) {
  const session = sessionFromRequest()
  if (!session) return context.render(<SetupNeeded />)
  let permissions = signedIn()?.permissions ?? null
  let can = (key: string) => permissions === null || permissions.includes(key)
  let job = { id: jobId, title: 'Job' }
  let criteria: RediscoveryCriterion[] = []
  let candidates: RediscoveryCandidate[] = []
  let buckets: Record<string, number> = {}
  let sequences: Sequence[] = []
  try {
    let found = await getJob(session, jobId)
    job = { id: found.id, title: found.title }
    criteria = (await getRediscoveryCriteria(session, jobId)).criteria
    let queue = await listRediscoveryQueue(session, jobId, bucket ? { bucket } : {})
    candidates = queue.data
    buckets = queue.meta?.buckets ?? {}
    if (can('sequence.enroll')) sequences = (await listSequences(session)).data
  } catch (caught) {
    error = error ?? message(caught)
  }
  return context.render(
    <RediscoveryPage
      job={job}
      criteria={criteria}
      candidates={candidates}
      buckets={buckets}
      bucket={bucket}
      sequences={sequences}
      canManage={can('project.manage')}
      canEnroll={can('sequence.enroll')}
      orgQuery={orgQuery(context.url)}
      notice={notice}
      error={error}
    />,
  )
}
