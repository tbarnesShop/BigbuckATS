// Isolated UI fixture. No Rails credentials or live records; not mapped by the application router.
import { createRouter } from 'remix/router'
import { render } from 'remix/middleware/render'
import { staticFiles } from 'remix/middleware/static'
import { assets, renderAssets } from '../app/assets.ts'
import { LabPage, LabEntry, LabUnavailable } from '../app/actions/lab/pages.tsx'
import { surfaceValue, type CatalogItem, type Step } from '../app/data/lab/types.ts'
const catalog: CatalogItem[] = [
  {
    name: 'createPerson',
    description: 'Create a disposable sample person.',
    method: 'POST',
    path: '/v1/people',
    write: true,
    available: true,
    inputSchema: { type: 'object', properties: { body: { type: 'object' } }, required: ['body'] },
    bodySchema: {
      type: 'object',
      properties: {
        person: {
          type: 'object',
          properties: { display_name: { type: 'string' } },
          required: ['display_name'],
        },
      },
      required: ['person'],
    },
  },
  {
    name: 'listPeople',
    description: 'List sample people.',
    method: 'GET',
    path: '/v1/people',
    write: false,
    available: true,
    inputSchema: { type: 'object', properties: { limit: { type: 'integer' } } },
  },
  {
    name: 'layoutFixture',
    description: 'Common lab layout fixture — four fields and a JSON draft.',
    method: 'POST',
    path: '/fixture',
    write: true,
    available: true,
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        limit: { type: 'integer' },
        enabled: { type: 'boolean' },
        body: { type: 'object' },
      },
      required: ['body'],
    },
    bodySchema: { type: 'object' },
  },
]
const steps: Step[] = [
  {
    id: 'create',
    title: 'Create a sample person',
    detail: 'Start with disposable sample inputs.',
    api: 'createPerson',
    mcp: 'createPerson',
    command: 'bigbuck person create --name Sample',
    args: { body: { person: { display_name: 'Sample person' } } },
  },
  {
    id: 'list',
    title: 'List people',
    detail: 'Inspect a short page.',
    api: 'listPeople',
    mcp: 'listPeople',
    command: 'bigbuck person list',
    args: { limit: 2 },
  },
]
export function labFixture() {
  const router = createRouter({
    middleware: [staticFiles('./public', { index: false }), render({ assets: renderAssets })],
  })
  router.get(
    '/assets/*path',
    async (context) => (await assets!.fetch(context.request)) ?? new Response(null, { status: 404 }),
  )
  router.get('/lab-unavailable', (context) =>
    context.render(
      <LabUnavailable
        surface="api"
        mode="explore"
        persona="Fixture persona"
        sandbox="api"
        generation={1}
        resetsAt={new Date(Date.now() + 3600000).toISOString()}
        message="The demo is busy. Wait a moment, then try again."
        retryPath="/lab?operation=listPeople"
      />,
      { status: 429 },
    ),
  )
  router.get('/lab', (context) =>
    context.render(
      <LabPage
        surface={surfaceValue(context.url.searchParams.get('surface') ?? 'api')}
        mode="explore"
        persona="Fixture persona"
        personaId={context.url.searchParams.get('persona') ?? 'fixture-persona'}
        organizationId="fixture-org"
        sandbox={surfaceValue(context.url.searchParams.get('surface') ?? 'api')}
        generation={Number(context.url.searchParams.get('generation') ?? 1)}
        resetsAt={context.url.searchParams.get('resetsAt') ?? '2099-01-01T00:00:00Z'}
        catalog={catalog}
        story={{
          title: 'Draft recovery fixture',
          intro: 'Isolated UI verification; no live records.',
          steps,
        }}
        completed={[]}
        viewer={{ permissions: [] }}
        initialOperation={context.url.searchParams.get('operation') ?? undefined}
        initialStep={context.url.searchParams.get('step') ?? undefined}
      />,
    ),
  )
  router.get('/session', (context) => {
    const selected = context.url.searchParams.has('surface')
    const surface =
      context.url.searchParams.get('surface') === 'cli'
        ? 'cli'
        : context.url.searchParams.get('surface') === 'mcp'
          ? 'mcp'
          : context.url.searchParams.get('surface') === 'ui'
            ? 'ui'
            : 'api'
    const mode =
      context.url.searchParams.get('mode') === 'connect'
        ? 'connect'
        : context.url.searchParams.get('mode') === 'compare'
          ? 'compare'
          : 'explore'
    const unavailable = context.url.searchParams.has('unavailable')
    return context.render(
      <LabEntry
        surface={surface}
        mode={mode}
        selected={selected}
        operation={context.url.searchParams.get('operation') ?? undefined}
        step={context.url.searchParams.get('step') ?? undefined}
        error={unavailable ? 'Fixture sandbox unavailable.' : undefined}
        status={
          selected && !unavailable
            ? {
                sandbox: {
                  surface: mode === 'connect' ? 'cli' : surface,
                  organization_id: 'fixture-org',
                  generation: 1,
                  state: 'ready',
                  resets_at: '2099-01-01T00:00:00Z',
                  shared: true,
                },
                roles: [
                  {
                    email: 'fixture@example.test',
                    name: 'Fixture persona',
                    role_key: 'recruiter',
                    role_name: 'Recruiter',
                    permissions: ['person.read'],
                  },
                ],
              }
            : undefined
        }
      />,
    )
  })
  router.get('/lab/status', () =>
    Response.json({
      story: { title: 'Draft recovery fixture', intro: 'Isolated UI verification; no live records.', steps },
      completed: [],
      sandbox: { generation: 1 },
    }),
  )
  router.post('/lab/execute', async (context) => {
    const input = await context.request.json()
    return Response.json({
      ok: true,
      status: 200,
      duration: 1,
      output:
        input.name === 'layoutFixture'
          ? {
              lines: Array.from(
                { length: 200 },
                (_, index) => `Sample output ${index + 1}: ${'long-identifier-'.repeat(16)}`,
              ),
            }
          : { fixture: true, input },
      links: [],
    })
  })
  router.get('/docs', () => new Response('Fixture destination'))
  return router
}
