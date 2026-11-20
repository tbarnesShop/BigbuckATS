import type { Handle } from 'remix/component'
import { Shell } from '../../ui/shell.tsx'
import { routes } from '../../routes.ts'
import { Brand } from '../../ui/brand.tsx'
import { ThemeToggle } from '../../ui/app-nav.tsx'
import { Workbench } from './public/workbench.tsx'
import { LiveBanner } from './public/live-banner.tsx'
import type { StatusResponse } from '../../data/lab/client.ts'
import type { CatalogItem, Mode, Story, Surface } from '../../data/lab/types.ts'

export function LabHeader() {
  return () => (
    <>
      <a class="skip-link" href="#main">
        Skip to content
      </a>
      <header class="lab-header">
        <div class="lab-brand-group">
          <Brand class="lab-brand" href="/session" />
        </div>
        <nav aria-label="Lab navigation">
          <a href="/session">Lab</a>
          <a href="/docs">Docs</a>
          <a class="lab-nav-careers" href={routes.careersIndex.href()}>
            Careers
          </a>
        </nav>
        <ThemeToggle variant="bar" />
      </header>
    </>
  )
}
const interfaces = [
  {
    key: 'ui',
    audience: 'The recruiting app',
    title: 'UI',
    lead: 'Take the wheel.',
    preview: ['Application review', 'Ava Chen → Phone screen', 'Ready for your next move'],
    detail: '',
    cta: 'Open the app',
  },
  {
    key: 'mcp',
    audience: 'For AI agents',
    title: 'MCP',
    lead: 'Pull on a thread.',
    preview: ['Agent tools', 'gql_job_pipeline', '→ stages, applications, people'],
    detail: 'Inspect the permissions behind each result.',
    cta: 'Explore tools',
  },
  {
    key: 'api',
    audience: 'For developers',
    title: 'API',
    lead: 'Make something happen.',
    preview: ['Request → response', 'POST /v1/people', '201 Created'],
    detail: '',
    cta: 'Try a request',
  },
  {
    key: 'cli',
    audience: 'From your terminal',
    title: 'CLI',
    lead: 'Stay in your flow.',
    preview: ['From your terminal', '$ bigbuck person list', 'Ava Chen    candidate'],
    detail: '',
    cta: 'Try a command',
  },
] as const
export function LabEntry(
  handle: Handle<{
    surface: Surface
    mode: Mode
    selected?: boolean
    status?: StatusResponse
    error?: string
    operation?: string
    step?: string
  }>,
) {
  return () => {
    const { surface, mode, status, error, operation, step } = handle.props
    const selected = handle.props.selected ?? !!status
    const personas =
      surface === 'ui'
        ? ['owner', 'admin', 'recruiter', 'hiring_manager'].flatMap((key) => {
            const persona = status?.roles.find((role) => role.role_key === key)
            return persona ? [persona] : []
          })
        : (status?.roles ?? [])
    const context = { ...(operation ? { operation } : {}), ...(step ? { step } : {}) }
    const destination = (nextSurface: Surface, nextMode = mode) =>
      `/session?${new URLSearchParams({ ...context, surface: nextSurface, mode: nextMode })}`
    return (
      <Shell title="Interactive lab" bare>
        <div class="lab-root">
          <LabHeader />
          <main class={`lab-entry ${selected ? '' : 'lab-public-entry'}`} id="main">
            {selected ? (
              <header class="lab-entry-heading">
                <p class="lab-eyebrow">Interactive lab</p>
                <h1>{surface.toUpperCase()} lab</h1>
                <p>Their permissions apply to every request.</p>
              </header>
            ) : (
              <header class="lab-entry-heading lab-public-heading">
                <img class="lab-public-mark" src="/bigbuck-mark.png" alt="" width="96" height="96" />
                <div>
                  <h1>
                    <span class="lab-headline-accent">Agent first</span>{' '}
                    <span class="lab-nowrap">CRM + ATS</span>
                  </h1>
                  <p class="lab-public-intro">A data layer built with agents as first-class users.</p>
                  <p class="lab-note">Pick an interface. Sample data is disposable.</p>
                  <p class="lab-public-actions">
                    <a class="lab-primary" href={routes.careersIndex.href()}>
                      View the careers site →
                    </a>
                  </p>
                </div>
              </header>
            )}
            {selected ? null : (
              <div class="lab-card-grid">
                {interfaces.map((card) => (
                  <a class="lab-card" href={destination(card.key)} key={card.key}>
                    <span class="lab-card-interface">
                      {card.title}
                      <span class="lab-card-audience">{card.audience}</span>
                    </span>
                    <h2>{card.lead}</h2>
                    {card.detail ? <p>{card.detail}</p> : null}
                    <div class={`lab-preview lab-preview-${card.key}`} aria-hidden="true">
                      <span class="lab-preview-label">{card.preview[0]}</span>
                      <code>{card.preview[1]}</code>
                      <code class="lab-preview-outcome">{card.preview[2]}</code>
                    </div>
                    <span class="lab-card-cta">{card.cta} →</span>
                  </a>
                ))}
              </div>
            )}
            {error ? (
              <div role="alert" class="lab-error">
                {error} <a href={destination(surface)}>Try again</a>
              </div>
            ) : null}
            {status ? (
              <section class="lab-personas" aria-labelledby="persona-heading">
                <h2 id="persona-heading">Choose a persona</h2>
                {mode === 'connect' ? (
                  <p class="lab-note">Connect uses the shared tools sandbox across MCP, API and CLI.</p>
                ) : null}
                <div class={`persona-grid ${surface === 'ui' ? 'persona-grid-ui' : ''}`}>
                  {personas.map((role) => (
                    <form key={role.email} method="post" action="/lab">
                      <input type="hidden" name="operation" value={operation ?? ''} />
                      <input type="hidden" name="step" value={step ?? ''} />
                      <input type="hidden" name="surface" value={surface} />
                      <input type="hidden" name="mode" value={mode} />
                      <input type="hidden" name="generation" value={status.sandbox.generation} />
                      <input type="hidden" name="email" value={role.email} />
                      <button class="persona" type="submit">
                        <span class="persona-avatar" aria-hidden="true">
                          {role.name
                            .split(' ')
                            .map((n) => n[0])
                            .slice(0, 2)
                            .join('')}
                        </span>
                        <span>
                          <strong>{role.name}</strong>
                          <span>
                            {role.role_name.replaceAll('_', ' ')} · {role.permissions.length} permissions
                          </span>
                          <small>
                            {role.role_key === 'hiring_manager'
                              ? 'Scoped to their hiring team'
                              : role.permissions.includes('person.read_restricted')
                                ? 'Restricted people visible within their scope'
                                : 'Public people within their scope'}
                          </small>
                        </span>
                        <span class="persona-go" aria-hidden="true">
                          →
                        </span>
                      </button>
                    </form>
                  ))}
                </div>
                <p class="lab-note">Sample data resets on a schedule. Destructive actions are blocked.</p>
              </section>
            ) : null}
            <footer class="lab-footer">
              <span>BigBuck lab</span>
              <a href="/docs">Read the documentation</a>
            </footer>
          </main>
        </div>
      </Shell>
    )
  }
}
export function LabUnavailable(
  handle: Handle<{
    surface: Surface
    mode: Mode
    persona: string
    sandbox: Surface
    generation: number
    resetsAt: string
    message: string
    retryPath: string
  }>,
) {
  return () => {
    const p = handle.props
    return (
      <Shell title={`${p.surface.toUpperCase()} lab unavailable`} bare>
        <div class="demo-frame lab-root">
          <LiveBanner
            initialNow={Date.now()}
            persona={p.persona}
            surface={p.surface}
            sandbox={p.sandbox}
            generation={p.generation}
            resetsAt={p.resetsAt}
            mode={p.mode}
          />
          <LabHeader />
          <main class="lab-workspace" id="main">
            <div class="workbench-top">
              <h1>{p.surface === 'ui' ? 'Recruiting workspace' : `${p.surface.toUpperCase()} lab`}</h1>
            </div>
            <section class="execution-panel lab-unavailable" aria-label="Workspace unavailable">
              <h2>Workspace unavailable</h2>
              <p role="alert">{p.message}</p>
              <p>
                Your persona is still selected. Try again to reopen the workspace; nothing will run
                automatically.
              </p>
              <div class="run-row">
                <a class="lab-primary" href={p.retryPath}>
                  Try again
                </a>
              </div>
            </section>
          </main>
        </div>
      </Shell>
    )
  }
}
export function LabPage(
  handle: Handle<{
    surface: Surface
    mode: Mode
    persona: string
    organizationId: string
    personaId: string
    sandbox: Surface
    generation: number
    resetsAt: string
    catalog: CatalogItem[]
    story: Story
    completed: string[]
    viewer: import('../../data/lab/types.ts').Json
    initialOperation?: string
    initialStep?: string
  }>,
) {
  return () => {
    const props = handle.props
    return (
      <Shell title={`${props.surface.toUpperCase()} workbench`} bare>
        <div class="demo-frame lab-root">
          <LiveBanner
            initialNow={Date.now()}
            persona={props.persona}
            surface={props.surface}
            sandbox={props.sandbox}
            generation={props.generation}
            resetsAt={props.resetsAt}
            mode={props.mode}
          />
          <LabHeader />
          <main class="lab-workspace" id="main">
            <Workbench {...props} />
          </main>
          <footer class="lab-footer">
            <span>Actual requests. Shared sample data. No model required.</span>
            <a href="/docs/interop">How the interfaces connect →</a>
          </footer>
        </div>
      </Shell>
    )
  }
}
