import { labRequest, requireLab } from './client.ts'
import type { Story, Step } from './types.ts'

export async function storyContext() {
  const current = requireLab()
  const suffix = current.lab.runKey
  const name = `Nova Lab ${suffix}`,
    email = `nova-${suffix}@example.test`,
    poolName = `Lab pool ${current.lab.mode} ${suffix}`
  const [people, existing, jobs, pools, applications, offers] = await Promise.all([
    labRequest(`/v1/people?q=${encodeURIComponent(name)}`),
    labRequest('/v1/people?q=Ava'),
    labRequest('/v1/jobs'),
    labRequest('/v1/projects'),
    labRequest('/v1/applications'),
    labRequest('/v1/offers'),
  ])
  const list = (response: { status: number; body: any }): any[] =>
    response.status === 200 && Array.isArray(response.body.data) ? response.body.data : []
  const candidate = list(people).find((p) => p.display_name === name)
  const ava = list(existing).find((p) => p.primary_email === 'ava.chen@example.com') ?? list(existing)[0]
  const job = list(jobs)[0]
  const issuedPool = current.lab.evidence?.pool
  const resolvedPool =
    issuedPool && issuedPool !== 'observed' ? await labRequest(`/v1/projects/${issuedPool}`) : null
  const pool =
    resolvedPool?.status === 200 && resolvedPool.body.name === poolName
      ? resolvedPool.body
      : list(pools).findLast((p) => p.name === poolName)
  const members = pool ? await labRequest(`/v1/projects/${pool.id}/members`) : null
  const person = current.lab.mode === 'compare' ? ava : candidate
  const membership = members && list(members).find((m) => m.person_id === person?.id)
  return {
    name,
    email,
    poolName,
    person,
    ava,
    job,
    pool,
    membership,
    application: list(applications)[0],
    offer: list(offers)[0],
  }
}
export async function storyFor(): Promise<{ story: Story; completed: string[] }> {
  const current = requireLab()
  const refs = await storyContext()
  const personId = refs.person?.id ?? refs.ava?.id ?? ''
  const find: Step = {
    id: 'find',
    title: 'Find someone already here',
    detail: 'Look up Ava in the existing talent network.',
    permission: 'person.read',
    api: 'listPeople',
    mcp: 'listPeople',
    args: { q: 'Ava' },
    command: 'bigbuck person list',
    ui: '/people?q=Ava',
    check: 'person',
  }
  const create: Step = {
    id: 'person',
    title: 'Create a sample person',
    detail: 'A person is the durable CRM record, independent of any application.',
    permission: 'person.create',
    surface: 'api',
    api: 'createPerson',
    mcp: 'createPerson',
    args: { body: { person: { display_name: refs.name, email: refs.email } } },
    command: `bigbuck person create --name "${refs.name}" --email ${refs.email}`,
    check: 'person',
  }
  const pool: Step = {
    id: 'pool',
    title: 'Make a talent pool',
    detail: 'Give this relationship somewhere to live beyond one job.',
    permission: 'project.manage',
    api: 'createProject',
    mcp: 'createProject',
    args: { body: { project: { name: refs.poolName } } },
    command: `bigbuck project create --name "${refs.poolName}"`,
    ui: `/pools/new?name=${encodeURIComponent(refs.poolName)}`,
    check: 'pool',
  }
  const add: Step = {
    id: 'member',
    title: 'Add the person to your pool',
    detail: 'Uses the real membership endpoint. Create the pool first.',
    permission: 'project.manage',
    surface: 'cli',
    api: 'addProjectMember',
    mcp: 'addProjectMember',
    args: { id: refs.pool?.id ?? '', body: { member: { person_id: personId } } },
    command: `bigbuck project add ${refs.pool?.id ?? '<pool-id>'} ${personId || '<person-id>'}`,
    ui: refs.pool ? `/pools/${refs.pool.id}` : '/pools',
    check: 'member',
  }
  let story: Story
  if (current.lab.mode === 'compare')
    story = {
      title: 'One CRM task. Four interfaces.',
      intro:
        'Find Ava, create your pool, and connect the two. Each interface has its own sample workspace; your task name follows you.',
      steps: [find, pool, add],
    }
  else if (current.lab.mode === 'connect')
    story = {
      title: 'Follow a record across the system',
      intro:
        'Every step stays in the CLI workspace—even when you open the UI. Try switching interfaces mid-story.',
      steps: [
        create,
        {
          id: 'inspect',
          title: 'Inspect through MCP',
          detail: 'Fetch the same person with applications and typed custom fields.',
          surface: 'mcp',
          permission: 'person.read',
          mcp: 'gql_person',
          args: { id: refs.person?.id ?? '' },
          check: 'person',
        },
        { ...pool, surface: 'cli' },
        add,
        {
          id: 'open',
          title: 'Continue in the UI',
          detail: 'Open the actual person record you just created.',
          surface: 'ui',
          ui: refs.person ? `/people/${refs.person.id}` : '/people',
        },
      ],
    }
  else if (current.lab.surface === 'ui')
    story = {
      title: 'A day in recruiting',
      intro: 'Explore applicants, interview evidence, and offers as your selected persona.',
      steps: [
        {
          id: 'review',
          title: 'Review an applicant',
          detail: 'Open the application and its pipeline history.',
          ui: refs.application ? `/applications/${refs.application.id}` : '/applications',
          permission: 'application.read',
        },
        {
          id: 'feedback',
          title: 'Inspect interview feedback',
          detail: 'See the existing notes and scorecards.',
          ui: '/interviews',
          permission: 'application.read',
        },
        {
          id: 'offer',
          title: 'Explore an offer',
          detail: 'Inspect the offer workflow and role boundaries.',
          ui: refs.offer ? `/offers/view/${refs.offer.id}` : '/offers',
          permission: 'offer.read',
        },
      ],
    }
  else if (current.lab.surface === 'mcp')
    story = {
      title: 'Investigate a hiring pipeline',
      intro: 'Discover tools, inspect their inputs, and ask the system for actual context.',
      steps: [
        {
          id: 'identity',
          title: 'Who is this agent?',
          detail: 'Inspect the agent, its human owner, and effective permissions.',
          mcp: 'gql_whoami',
          args: {},
        },
        {
          id: 'pipeline',
          title: 'Read a job pipeline',
          detail: 'Get stages and visible applications in one GraphQL tool call.',
          mcp: 'gql_job_pipeline',
          args: { id: refs.job?.id ?? '' },
          permission: 'job.read',
        },
        {
          id: 'person',
          title: 'Inspect a person',
          detail: 'Fetch their applications and typed custom fields.',
          mcp: 'gql_person',
          args: { id: refs.ava?.id ?? '' },
          permission: 'person.read',
        },
      ],
    }
  else if (current.lab.surface === 'cli')
    story = {
      title: 'Set up a recruiting team',
      intro:
        'Use real commands and sample files. Owner can apply configuration; other roles may encounter a useful refusal.',
      steps: [
        {
          id: 'init',
          title: 'Create configuration files',
          detail: 'Writes YAML in your temporary demo directory.',
          command: 'bigbuck config init --preset recruiting-team --dir ./bigbuck',
        },
        {
          id: 'plan',
          title: 'Inspect a configuration plan',
          detail: 'Preview changes before applying them.',
          permission: 'config.plan',
          command: 'bigbuck config plan --dir ./bigbuck',
          check: 'plan',
        },
        {
          id: 'apply',
          title: 'Apply the plan',
          detail: 'Paste the returned plan ID into the command.',
          permission: 'config.apply',
          command: `bigbuck config apply --plan-id ${current.lab.evidence?.plan ?? '<plan-id>'}`,
          check: 'applied',
        },
        {
          id: 'preview',
          title: 'Preview a CSV import',
          detail: 'sample.csv contains two fictional contacts.',
          permission: 'import.manage',
          command: 'bigbuck import csv --file sample.csv --dry-run',
          check: 'import',
        },
        {
          id: 'import',
          title: 'Import the contacts',
          detail: 'Run without dry-run to apply the staged rows.',
          permission: 'import.manage',
          command: 'bigbuck import csv --file sample.csv',
          check: 'import',
        },
      ],
    }
  else
    story = {
      title: 'Build a tiny CRM workflow',
      intro: 'Create a person, make a pool, then connect them.',
      steps: [create, pool, add],
    }
  const completed: string[] = []
  for (const step of story.steps) {
    if (
      step.check === 'person' &&
      (current.lab.mode === 'compare' || step.id === 'inspect'
        ? (current.lab.evidence?.[step.id] || current.lab.evidence?.[`ui:${step.id}`]) &&
          (current.lab.mode === 'compare' ? refs.ava : refs.person)
        : refs.person)
    )
      completed.push(step.id)
    if (!step.check && (current.lab.evidence?.[step.id] || current.lab.evidence?.[`ui:${step.id}`]))
      completed.push(step.id)
    if (step.check === 'pool' && refs.pool) completed.push(step.id)
    if (step.check === 'member' && refs.membership) completed.push(step.id)
  }
  for (const [step, key, path] of [
    ['preview', 'preview', 'imports'],
    ['import', 'import', 'imports'],
    ['plan', 'plan', 'config/plans'],
    ['apply', 'apply', 'config/plans'],
  ] as const) {
    const id = current.lab.evidence?.[key]
    if (!id || id === 'observed') continue
    const response = await labRequest(`/v1/${path}${path === 'imports' ? `/${id}` : ''}`)
    if (response.status !== 200) continue
    const row =
      path === 'imports' ? response.body : (response.body.data ?? []).find((row: any) => row.id === id)
    if (!row) continue
    if (
      (step === 'preview' && row.status === 'dry_run') ||
      (step === 'import' && row.status === 'applied' && row.error_count === 0) ||
      (step === 'plan' && ['open', 'applied'].includes(row.status)) ||
      (step === 'apply' && row.status === 'applied')
    )
      completed.push(step)
  }
  return { story, completed }
}
