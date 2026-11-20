import { createController } from 'remix/router'
import { randomUUID } from 'node:crypto'
import { signedIn, signIn, rememberLab, rememberPermissions } from '../../data/auth.ts'
import { routes } from '../../routes.ts'
import {
  control,
  labRequest,
  requireLab,
  LabError,
  type StartResponse,
  type StatusResponse,
} from '../../data/lab/client.ts'
import { apiCatalog } from '../../data/lab/catalog.ts'
import { modeValue, surfaceValue, type Result, type Surface, type Mode } from '../../data/lab/types.ts'
import { mcpCatalog, runApi, runCli, runMcp } from '../../data/lab/runners.ts'
import { storyFor } from '../../data/lab/stories.ts'
import { LabPage, LabEntry, LabUnavailable } from './pages.tsx'

const redirect = (path: string) => new Response(null, { status: 303, headers: { Location: path } })
const json = (data: unknown, status = 200) =>
  Response.json(data, { status, headers: { 'Cache-Control': 'no-store' } })
/** Browser GETs of lab JSON endpoints get a wrapping page so long lines do not overflow on phones. */
function labPayload(request: Request, data: unknown, status = 200) {
  const accept = request.headers.get('accept') ?? ''
  // Browser navigations send text/html; lab fetch() calls use */* or application/json.
  if (/\btext\/html\b/.test(accept)) {
    const body = JSON.stringify(data, null, 2)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
    return new Response(
      `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Lab</title><style>body{margin:0;background:#111;color:#eee;font:14px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace}pre{margin:0;padding:16px;white-space:pre-wrap;overflow-wrap:anywhere}</style></head><body><pre>${body}</pre></body></html>`,
      {
        status,
        headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' },
      },
    )
  }
  return json(data, status)
}
const sessionExpired = (error: unknown) =>
  error instanceof LabError &&
  (error.status === 401 || ['sandbox_expired', 'invalid_token', 'draft_scope_changed'].includes(error.code))
function checkViewer(viewer: { status: number; body: any }) {
  if (viewer.status === 200) return
  throw new LabError(
    viewer.status,
    viewer.body?.code ?? 'lab_session_unavailable',
    viewer.status === 429
      ? 'The demo is busy. Wait a moment, then try again.'
      : (viewer.body?.title ??
          (viewer.status === 401
            ? 'This demo session has expired. Choose a persona to start again.'
            : 'The workspace could not load. Try again.')),
  )
}
function unavailable(
  context: { url: URL; render: (element: any, init?: ResponseInit) => any },
  current: NonNullable<ReturnType<typeof signedIn>>,
  surface: Surface,
  mode: Mode,
  error: unknown,
) {
  const lab = current.lab!
  return context.render(
    <LabUnavailable
      surface={surface}
      mode={mode}
      persona={current.name ?? current.email ?? 'Demo persona'}
      sandbox={lab.sandbox}
      generation={lab.generation}
      resetsAt={lab.resetsAt}
      message={error instanceof Error ? error.message : 'The workspace could not load. Try again.'}
      retryPath={`/lab?${new URLSearchParams({ ...Object.fromEntries(context.url.searchParams), surface, mode })}`}
    />,
    { status: error instanceof LabError ? error.status : 503 },
  )
}
export async function entryData(url: URL) {
  const surface = surfaceValue(url.searchParams.get('surface'))
  const mode = modeValue(url.searchParams.get('mode'))
  let status: StatusResponse | undefined, error: string | undefined
  if (url.searchParams.has('surface')) {
    try {
      status = await control(`/demo/sandboxes/${mode === 'connect' ? 'cli' : surface}`)
    } catch (e) {
      error = String(e instanceof Error ? e.message : e)
    }
  }
  return {
    selected: url.searchParams.has('surface'),
    surface,
    mode,
    status,
    error,
    operation: url.searchParams.get('operation') ?? undefined,
    step: url.searchParams.get('step') ?? undefined,
  }
}
export async function entry(context: { url: URL; render: (element: any) => any }) {
  const current = signedIn()?.lab
  if (
    current &&
    (context.url.searchParams.has('operation') ||
      context.url.searchParams.has('step') ||
      context.url.searchParams.has('prepare'))
  ) {
    const surface = surfaceValue(context.url.searchParams.get('surface') ?? current.surface)
    const mode = modeValue(context.url.searchParams.get('mode') ?? current.mode)
    if ((mode === 'connect' ? 'cli' : surface) === current.sandbox)
      return redirect(
        `/lab?${new URLSearchParams({ ...Object.fromEntries(context.url.searchParams), surface, mode })}`,
      )
  }
  return context.render(<LabEntry {...await entryData(context.url)} />)
}
export const labController = createController(routes.lab, {
  actions: {
    async index(context) {
      const current = signedIn()
      if (!current?.lab) return redirect(`/session${context.url.search}`)
      const surface = surfaceValue(context.url.searchParams.get('surface') ?? current.lab.surface)
      const mode = modeValue(context.url.searchParams.get('mode') ?? current.lab.mode)
      const sandbox = mode === 'connect' ? 'cli' : surface
      if (sandbox !== current.lab.sandbox)
        return redirect(
          `/session?${new URLSearchParams({ ...Object.fromEntries(context.url.searchParams), surface, mode })}`,
        )
      rememberLab({ ...current.lab, surface, mode })
      if (surface === 'ui' && Date.now() >= Date.parse(current.lab.resetsAt))
        return redirect(`/session?${new URLSearchParams({ surface, mode })}`)
      try {
        const viewer = await labRequest('/v1/sessions/current')
        checkViewer(viewer)
        if (surface === 'ui') {
          const stepId = context.url.searchParams.get('step')
          if (stepId) {
            const { story } = await storyFor()
            const step = story.steps.find((step) => step.id === stepId && step.ui)
            if (step?.ui) {
              const destination = new URL(step.ui, context.url)
              destination.searchParams.set('labStep', step.id)
              return redirect(destination.pathname + destination.search)
            }
          }
          return redirect('/today')
        }
        const catalog = surface === 'mcp' ? await mcpCatalog() : apiCatalog()
        const identity = await labRequest('/demo/permissions', { agent: surface === 'mcp' })
        const story = await storyFor()
        return context.render(
          <LabPage
            surface={surface}
            mode={mode}
            organizationId={current.organizationId ?? ''}
            personaId={current.userId ?? ''}
            persona={current.name ?? current.email ?? 'Demo persona'}
            sandbox={sandbox}
            generation={current.lab.generation}
            resetsAt={current.lab.resetsAt}
            catalog={catalog}
            story={story.story}
            completed={story.completed}
            viewer={identity.status === 200 ? identity.body : viewer.body}
            initialOperation={context.url.searchParams.get('operation') ?? undefined}
            initialStep={context.url.searchParams.get('step') ?? undefined}
          />,
        )
      } catch (error) {
        if (!sessionExpired(error)) return unavailable(context, current, surface, mode, error)
        return context.render(
          <LabEntry
            {...await entryData(new URL(`/session?surface=${surface}&mode=${mode}`, context.url))}
            error={error instanceof Error ? error.message : String(error)}
          />,
        )
      }
    },
    async action(context) {
      const form = await context.request.formData()
      const surface = surfaceValue(form.get('surface')),
        mode = modeValue(form.get('mode')),
        sandbox = mode === 'connect' ? 'cli' : surface
      const current = signedIn()
      const previous = current?.lab
      try {
        let email = String(form.get('email'))
        let generation = Number(form.get('generation'))
        if (form.get('intent') === 'switch-interface') {
          const source = requireLab()
          if (!source.demo || !source.email || !['mcp', 'api', 'cli'].includes(String(form.get('surface'))))
            throw new LabError(401, 'lab_session_required', 'Choose a demo persona to start.')
          if (Date.now() >= Date.parse(source.lab.resetsAt))
            throw new LabError(
              409,
              'sandbox_expired',
              'This demo session has expired. Choose a persona to start again.',
            )
          const viewer = await labRequest('/v1/sessions/current', { user: true })
          checkViewer(viewer)
          if (sandbox === source.lab.sandbox) {
            rememberLab({ ...source.lab, surface, mode })
            return redirect(`/lab?${new URLSearchParams({ surface, mode })}`)
          }
          const destination = await control<StatusResponse>(`/demo/sandboxes/${sandbox}`)
          if (
            !destination.roles.some(
              (persona) => persona.email === source.email && persona.role_key === source.roleKey,
            )
          )
            throw new LabError(
              409,
              'persona_unavailable',
              'Your selected persona is unavailable in this interface. Choose a persona to continue.',
            )
          // Identity comes from the authenticated cookie, never a posted persona field.
          email = source.email
          generation = destination.sandbox.generation
        }
        const started = await control<StartResponse>('/demo/sessions', {
          surface: sandbox,
          email,
          generation,
        })
        signIn({
          userId: started.user.id,
          token: started.session.token,
          email: started.user.email,
          name: started.user.name,
          organizationId: started.organization.id,
          organizationSlug: started.organization.slug,
          demo: true,
        })
        rememberPermissions({ permissions: started.permissions, roleKey: started.role_key })
        rememberLab({
          surface,
          sandbox,
          mode,
          generation: started.sandbox.generation,
          resetsAt: started.sandbox.resets_at,
          runKey: previous?.runKey ?? randomUUID().slice(0, 8),
          evidence:
            previous?.sandbox === sandbox &&
            previous.generation === started.sandbox.generation &&
            current?.userId === started.user.id
              ? previous.evidence
              : undefined,
          toolToken: started.tools.token,
          agentToken: started.tools.agent_token,
        })
        const operation = String(form.get('operation') ?? '')
        const step = String(form.get('step') ?? '')
        if (surface === 'ui' && !step) return redirect('/today')
        return redirect(
          `/lab${operation || step ? `?${new URLSearchParams({ ...(operation ? { operation } : {}), ...(step ? { step } : {}) })}` : ''}`,
        )
      } catch (error) {
        if (form.get('intent') === 'switch-interface' && current?.lab && !sessionExpired(error))
          return unavailable(context, current, current.lab.surface, current.lab.mode, error)
        return context.render(
          <LabEntry
            {...await entryData(new URL(`/session?surface=${surface}&mode=${mode}`, context.url))}
            error={error instanceof Error ? error.message : String(error)}
          />,
        )
      }
    },
  },
})
export const labExecuteController = createController(routes.labExecute, {
  actions: {
    async index() {
      return redirect('/lab')
    },
    async action(context) {
      let executing = false
      let executionResult: Result | undefined
      try {
        const current = requireLab()
        const identity = await labRequest('/demo/permissions', { agent: current.lab.surface === 'mcp' })
        if (identity.status !== 200)
          throw new LabError(
            identity.status,
            identity.body?.code ?? 'lab_session_unavailable',
            identity.body?.title ?? 'This demo session is unavailable. Choose a persona to restart.',
          )
        const input = (await context.request.json()) as {
          step?: string
          name?: string
          args?: Record<string, unknown>
          command?: string
          scope?: {
            organization: string
            persona: string
            sandbox: string
            generation: number
            surface: string
          }
          idempotencyKey?: string
        }
        if (
          input.scope &&
          (input.scope.organization !== current.organizationId ||
            input.scope.persona !== current.userId ||
            input.scope.sandbox !== current.lab.sandbox ||
            input.scope.generation !== current.lab.generation ||
            input.scope.surface !== current.lab.surface)
        )
          throw new LabError(
            409,
            'draft_scope_changed',
            'The authorized workspace changed. Choose a persona again; copy your old input before leaving.',
          )
        executing = true
        const data =
          current.lab.surface === 'mcp'
            ? await runMcp(String(input.name), input.args ?? {})
            : current.lab.surface === 'cli'
              ? await runCli(String(input.command))
              : await runApi(String(input.name), input.args ?? {}, input.idempotencyKey)
        executionResult = data
        const before = await storyFor()
        const step = before.story.steps.find((step) => step.id === input.step)
        const expected = current.lab.surface === 'mcp' ? step?.mcp : step?.api
        if (
          data.ok &&
          step &&
          (current.lab.surface === 'cli'
            ? input.command === step.command
            : input.name === expected &&
              Object.entries(step.args ?? {}).every(
                ([key, value]) => JSON.stringify(input.args?.[key]) === JSON.stringify(value),
              ))
        ) {
          const body = data.output as any
          const id = body?.id ?? body?.data?.id ?? body?.plan?.id
          rememberLab({
            ...current.lab,
            evidence: { ...current.lab.evidence, [step.id]: typeof id === 'string' ? id : 'observed' },
          })
        }
        return json({ ...data, ...(await storyFor()) })
      } catch (error) {
        if (executionResult)
          return json({
            ...executionResult,
            warning:
              'The request finished, but supporting context could not refresh. Your response is preserved.',
          })
        const outcome = executing ? (error instanceof LabError ? error.outcome : 'unknown') : undefined

        const e =
          error instanceof LabError
            ? error
            : new LabError(503, 'execution_failed', error instanceof Error ? error.message : String(error))
        return json(
          {
            ok: false,
            ...(outcome ? { outcome } : {}),
            status: e.status,
            error: e.message,
            output: { code: e.code, title: e.message },
            duration: 0,
            links: [],
          },
          e.status,
        )
      }
    },
  },
})
export const labStatusController = createController(
  { labStatus: routes.labStatus },
  {
    actions: {
      async labStatus(context) {
        try {
          const current = signedIn()
          if (!current?.lab)
            throw new LabError(401, 'lab_session_required', 'Choose a demo persona to start.')
          const response = await control<StatusResponse>(`/demo/sandboxes/${current.lab.sandbox}`)
          if (response.sandbox.generation !== current.lab.generation) {
            rememberLab({ ...current.lab, evidence: undefined })
            return labPayload(
              context.request,
              { error: 'The shared demo refreshed. Start again.', code: 'sandbox_expired' },
              409,
            )
          }
          return labPayload(context.request, { sandbox: response.sandbox, ...(await storyFor()) })
        } catch (error) {
          return labPayload(
            context.request,
            {
              error: error instanceof Error ? error.message : String(error),
              code: error instanceof LabError ? error.code : 'lab_unavailable',
            },
            error instanceof LabError ? error.status : 503,
          )
        }
      },
    },
  },
)
export const labInspectController = createController(
  { labInspect: routes.labInspect },
  {
    actions: {
      async labInspect(context) {
        try {
          requireLab()
          const kind = context.url.searchParams.get('kind') ?? ''
          const id = context.url.searchParams.get('id') ?? ''
          if (
            !['people', 'projects', 'jobs', 'applications', 'offers', 'audit'].includes(kind) ||
            !/^[0-9a-f-]{36}$/.test(id)
          )
            return labPayload(
              context.request,
              {
                error: 'Choose a record from the result.',
                hint: 'After a lab run, open Related records, or call /lab/inspect?kind=people|projects|jobs|applications|offers|audit&id=<uuid>.',
              },
              400,
            )
          const path = kind === 'audit' ? '/v1/events' : `/v1/${kind}/${id}`
          const response = await labRequest(path)
          return labPayload(context.request, response.body, response.status)
        } catch (error) {
          return labPayload(
            context.request,
            {
              error: error instanceof Error ? error.message : String(error),
              code: error instanceof LabError ? error.code : 'lab_unavailable',
            },
            error instanceof LabError ? error.status : 503,
          )
        }
      },
    },
  },
)
