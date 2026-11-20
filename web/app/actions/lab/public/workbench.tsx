import { validateInput } from './validation.ts'
import { clientEntry, on, ref, type Handle } from 'remix/component'
import type {
  CatalogItem,
  Mode,
  Result,
  Step,
  Story,
  Surface,
  Schema,
  RecordLink,
} from '../../../data/lab/types.ts'

import { Drafts, draftKey, memoryOnly, tabDraftStorage, clearStoredDrafts, type RawDraft } from './drafts.ts'

type Props = {
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
  viewer: import('../../../data/lab/types.ts').Json
  initialOperation?: string
  initialStep?: string
}
const pretty = (value: unknown) => (typeof value === 'string' ? value : JSON.stringify(value, null, 2))
function example(schema: Schema): unknown {
  if (schema.example !== undefined) return schema.example
  if (schema.default !== undefined) return schema.default
  if (schema.enum?.length) return schema.enum[0]
  if (schema.type === 'object' || schema.properties)
    return Object.fromEntries(
      Object.entries(schema.properties ?? {})
        .filter(([key]) => schema.required?.includes(key))
        .map(([key, s]) => [key, example(s)]),
    )
  if (schema.type === 'array') return []
  if (schema.type === 'boolean') return false
  if (schema.type === 'number' || schema.type === 'integer') return 1
  return ''
}
export const Workbench = clientEntry(import.meta.url, function Workbench(handle: Handle<Props>) {
  let query = '',
    selected = handle.props.initialOperation ?? (handle.props.surface === 'mcp' ? 'gql_whoami' : 'listPeople')
  let command = 'bigbuck person list',
    args: Record<string, string> = {},
    pending = false,
    error = '',
    output: Result | null = null
  let history: string[] = [],
    inspected: unknown = null,
    record: RecordLink | null = null,
    story = handle.props.story,
    completed = handle.props.completed
  let activeStep = handle.props.initialStep ?? '',
    expired = Date.now() >= Date.parse(handle.props.resetsAt)
  const identity = () =>
    JSON.stringify([
      handle.props.organizationId,
      handle.props.personaId,
      handle.props.sandbox,
      handle.props.surface,
      handle.props.generation,
      handle.props.catalog.map((item) => [item.name, item.inputSchema, item.bodySchema]),
    ])
  let lastIdentity = identity()
  const drafts = new Drafts(tabDraftStorage())
  let edited = false,
    recover = false,
    saved = false,
    notice = '',
    initialized = false
  let leave: (() => void) | undefined, recoveryDialog: HTMLDialogElement | undefined
  let origin = '',
    inspectionSequence = 0,
    pollSequence = 0
  let requestStatus = 'Ready · sample data',
    copyNotice = ''
  let staleDraft: RawDraft | undefined
  const catalog = () => handle.props.catalog.find((item) => item.name === selected)
  const key = () =>
    draftKey(
      {
        organization: handle.props.organizationId,
        persona: handle.props.personaId,
        sandbox: handle.props.sandbox,
        generation: handle.props.generation,
        surface: handle.props.surface,
      },
      selected,
      handle.props.surface === 'cli' ? 'bigbuck-cli-v1' : [catalog()?.inputSchema, catalog()?.bodySchema],
    )
  const raw = (): RawDraft => ({
    fields: args,
    command,
    edited,
    recover: recover && !expired && !!handle.props.organizationId && !!handle.props.personaId,
  })
  function save() {
    saved = drafts.save(key(), raw())
  }
  function edit() {
    error = ''
    requestStatus = 'Ready · sample data'
    edited = true
    save()
    handle.update()
  }
  function restore() {
    const draft = drafts.read(key())
    edited = draft?.edited ?? false
    recover = draft?.recover ?? false
    if (draft) {
      args = draft.fields
      command = draft.command
    }
    save()
    return !!draft
  }
  function selectionHistory(replace = false) {
    if (typeof window === 'undefined') return
    const url = new URL(location.href)
    url.searchParams.set('surface', handle.props.surface)
    url.searchParams.set('mode', handle.props.mode)
    if (activeStep) url.searchParams.set('step', activeStep)
    else url.searchParams.delete('step')
    if (handle.props.surface !== 'cli' && handle.props.surface !== 'ui')
      url.searchParams.set('operation', selected)
    else url.searchParams.delete('operation')
    if (url.href !== location.href) {
      if (replace) window.history.replaceState(null, '', url)
      else window.history.pushState(null, '', url)
    }
  }
  function choose(name: string, update = true) {
    if (update && (pending || expired)) return
    if (
      !handle.props.catalog.some((item) => item.name === name) &&
      handle.props.surface !== 'cli' &&
      handle.props.surface !== 'ui'
    )
      return
    if (initialized) save()
    selected = name
    if (handle.props.surface === 'cli') command = name
    activeStep = ''
    args = {}
    error = ''
    requestStatus = 'Ready · sample data'
    notice = ''
    const item = catalog()
    if (item) {
      for (const [key, schema] of Object.entries(item.inputSchema.properties ?? {})) {
        const value =
          key === 'body'
            ? pretty(example(item.bodySchema ?? { type: 'object' }))
            : (item.inputSchema.required ?? []).includes(key) || schema.enum
              ? example(schema)
              : schema.type === 'object' || schema.type === 'array'
                ? '{}'
                : ''
        args[key] = typeof value === 'object' ? pretty(value) : String(value ?? '')
      }
    }
    restore()
    initialized = true
    if (update) {
      selectionHistory()
      handle.update()
    }
  }
  function loadStep(step: Step) {
    args = Object.fromEntries(
      Object.entries(step.args ?? {}).map(([k, v]) => [k, typeof v === 'object' ? pretty(v) : String(v)]),
    )
    if (step.command) command = step.command
    edited = false
    notice = 'Step inputs loaded. Nothing has run.'
    save()
  }
  function adopt(step: Step, update = true) {
    if (update && (pending || expired)) return
    const name =
      handle.props.surface === 'cli'
        ? step.command?.split(/\s+/).slice(0, 3).join(' ')
        : handle.props.surface === 'mcp'
          ? step.mcp
          : step.api
    choose(name ?? selected, false)
    activeStep = step.id
    if (edited) notice = 'Your draft is preserved. Use Load step inputs to replace it with this example.'
    else loadStep(step)
    if (update) {
      selectionHistory()
      handle.update()
    }
  }
  function expire() {
    expired = true
    requestStatus = 'Workspace expired · execution blocked'
    output = null
    record = null
    inspected = null
    completed = []
    history = []
    inspectionSequence++
    pollSequence++
    drafts.clear()
    recover = false
    saved = false
    // Keep exact input in memory for copying and the normal leave guard, never restoration.
    save()
  }
  async function inspect(link: RecordLink) {
    if (expired) return
    if (record?.id !== link.id || record?.kind !== link.kind) inspected = null
    record = link
    const scope = identity(),
      sequence = ++inspectionSequence
    try {
      const response = await fetch(`/lab/inspect?${new URLSearchParams({ kind: link.kind, id: link.id })}`)
      const data = await response.json()
      if (
        scope !== identity() ||
        expired ||
        sequence !== inspectionSequence ||
        record?.id !== link.id ||
        record.kind !== link.kind ||
        handle.signal.aborted
      )
        return
      inspected = data
      handle.update()
    } catch {
      /* Keep the previously inspected record on transient connection failure. */
    }
  }
  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      copyNotice = 'Copied to clipboard.'
    } catch {
      copyNotice = 'Copy failed. Select the content and copy it manually.'
    }
    handle.update()
  }
  async function execute() {
    if (Date.now() >= Date.parse(handle.props.resetsAt)) {
      expire()
      handle.update()
      return
    }
    if (pending || expired) return
    pollSequence++
    const scope = identity()
    const focused = document.activeElement instanceof HTMLElement ? document.activeElement : null
    const selection =
      focused instanceof HTMLInputElement || focused instanceof HTMLTextAreaElement
        ? ([focused.selectionStart, focused.selectionEnd] as const)
        : undefined
    const requestName = handle.props.surface === 'cli' ? command : selected
    const requestStep = activeStep
    const requestArgs = structuredClone(args)
    const requestCommand = command
    const requestScope = {
      organization: handle.props.organizationId,
      persona: handle.props.personaId,
      sandbox: handle.props.sandbox,
      generation: handle.props.generation,
      surface: handle.props.surface,
    }
    const requestId = crypto.randomUUID()
    const requestCatalog = catalog()
    let submitted = false
    pending = true
    requestStatus = `Running ${requestName}…`
    error = ''
    handle.update()
    try {
      const converted: Record<string, unknown> = {}
      for (const [key, value] of Object.entries(requestArgs)) {
        const schema = requestCatalog?.inputSchema.properties?.[key]
        if (value === '') continue
        if (schema?.type === 'boolean' && !['true', 'false'].includes(value))
          throw new SyntaxError(`${key} must be true or false`)
        if (
          (schema?.type === 'number' || schema?.type === 'integer') &&
          (!Number.isFinite(Number(value)) || (schema.type === 'integer' && !Number.isInteger(Number(value))))
        )
          throw new SyntaxError(`${key} must be a valid ${schema.type}`)
        converted[key] =
          (key === 'body' || schema?.type === 'object' || schema?.type === 'array') &&
          typeof value === 'string'
            ? JSON.parse(value)
            : schema?.type === 'integer' || schema?.type === 'number'
              ? Number(value)
              : schema?.type === 'boolean'
                ? value === 'true'
                : value
      }
      for (const required of requestCatalog?.inputSchema.required ?? []) {
        if (converted[required] === undefined && handle.props.surface !== 'cli')
          throw new SyntaxError(`${required} is required`)
      }
      if (handle.props.surface !== 'cli' && requestCatalog) {
        validateInput(converted, requestCatalog.inputSchema)
        if (requestCatalog.bodySchema && converted.body !== undefined)
          validateInput(converted.body, requestCatalog.bodySchema, 'body')
      }
      submitted = true
      const response = await fetch('/lab/execute', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          scope: requestScope,
          step: requestStep,
          name: requestName,
          args: converted,
          command: requestCommand,
          idempotencyKey: requestId,
        }),
      })
      const data = (await response.json()) as Result & { story?: Story; completed?: string[] }
      if (scope !== identity() || expired || handle.signal.aborted) return
      if (Date.now() >= Date.parse(handle.props.resetsAt)) {
        expire()
        return
      }
      origin = requestName
      output = data
      notice = data.warning ?? ''
      requestStatus =
        data.outcome === 'unknown'
          ? 'Request outcome unknown'
          : data.ok
            ? data.output == null || data.output === ''
              ? 'Completed · empty response'
              : `Completed · ${data.status}`
            : `Failed · ${data.status}`
      if (data.outcome === 'unknown')
        error = data.error ?? 'The request outcome is unknown. Check the record before retrying.'
      if (data.story) story = data.story
      if (data.completed) completed = data.completed
      if (handle.props.surface === 'cli')
        history = [requestCommand, ...history.filter((item) => item !== requestCommand)].slice(0, 8)
      if (
        (data.output as any)?.code === 'sandbox_expired' ||
        (data.output as any)?.code === 'invalid_token' ||
        (data.output as any)?.code === 'draft_scope_changed'
      )
        expire()
      if (data.links?.[0]) void inspect(data.links[0])
    } catch (e) {
      if (scope === identity() && !expired && !handle.signal.aborted) {
        requestStatus = submitted ? 'Request outcome unknown' : 'Input needs attention'
        error =
          e instanceof SyntaxError && !submitted
            ? `Invalid JSON: ${e.message}. Your input is preserved.`
            : `Request could not finish: ${e instanceof Error ? e.message : String(e)}. Its outcome may be unknown; check the record before retrying.`
      }
    } finally {
      if (scope === identity() && !handle.signal.aborted) {
        pending = false
        await handle.update()
        if (
          focused?.isConnected &&
          document.activeElement === document.body &&
          focused.closest('.execution-panel')
        ) {
          focused.focus({ preventScroll: true })
          if (
            selection &&
            selection[0] !== null &&
            selection[1] !== null &&
            (focused instanceof HTMLInputElement || focused instanceof HTMLTextAreaElement)
          )
            focused.setSelectionRange(selection[0], selection[1])
        }
      }
    }
  }
  if (handle.props.initialStep) {
    const step = story.steps.find((s) => s.id === handle.props.initialStep)
    if (step) adopt(step, false)
  } else {
    const first = story.steps.find((s) =>
      handle.props.surface === 'mcp' ? s.mcp : handle.props.surface === 'cli' ? s.command : s.api,
    )
    if (first && !handle.props.initialOperation) adopt(first, false)
    else choose(selected, false)
  }
  const initialSelection = selected
  if (typeof window !== 'undefined') {
    selectionHistory(true)
    window.addEventListener(
      'popstate',
      () => {
        if (pending || expired) {
          selectionHistory(true)
          return
        }
        const url = new URL(location.href)
        const step = story.steps.find((s) => s.id === url.searchParams.get('step'))
        const operation =
          url.searchParams.get('operation') ?? handle.props.initialOperation ?? initialSelection
        // Native response anchors also create history entries; they do not select another request.
        if (operation === selected && (step?.id ?? '') === activeStep) return
        if (step) adopt(step, false)
        else choose(operation, false)
        handle.update()
      },
      { signal: handle.signal },
    )
    window.addEventListener(
      'bigbuck:clear-lab-drafts',
      () => {
        drafts.clear()
        args = {}
        command = ''
        output = null
        record = null
        inspected = null
        history = []
        completed = []
        expired = true
        requestStatus = 'Signed out · execution blocked'
        inspectionSequence++
        pollSequence++
        edited = false
        recover = false
      },
      { signal: handle.signal },
    )
    window.addEventListener(
      'beforeunload',
      (event) => {
        if (drafts.unrecovered().length || pending) {
          event.preventDefault()
          event.returnValue = ''
        }
      },
      { signal: handle.signal },
    )
    function guard(event: Event, continueNavigation: () => void) {
      if (pending) {
        event.preventDefault()
        notice = 'Wait for the request to finish before leaving.'
        handle.update()
        return
      }
      save()
      if (!drafts.unrecovered().length) return
      event.preventDefault()
      leave = continueNavigation
      notice = ''
      handle.update()
      recoveryDialog?.showModal()
    }
    document.addEventListener(
      'click',
      (event) => {
        if (
          event.defaultPrevented ||
          event.button ||
          event.metaKey ||
          event.ctrlKey ||
          event.shiftKey ||
          event.altKey
        )
          return
        const anchor = (event.target as Element).closest<HTMLAnchorElement>('a[href]')
        if (!anchor || anchor.target === '_blank' || anchor.hasAttribute('download')) return
        const url = new URL(anchor.href)
        if (
          url.origin === location.origin &&
          url.pathname === location.pathname &&
          url.search === location.search
        )
          return
        guard(event, () => {
          location.assign(anchor.href)
        })
      },
      { capture: true, signal: handle.signal },
    )
    document.addEventListener(
      'submit',
      (event) => {
        const form = event.target as HTMLFormElement
        if (!form.action || form.closest('.execution-panel')) return
        guard(event, () => {
          if (new FormData(form).get('intent') === 'sign-out') {
            drafts.clear()
            clearStoredDrafts(tabDraftStorage())
          }
          form.submit()
        })
      },
      { capture: true, signal: handle.signal },
    )
    const timer = setInterval(async () => {
      if (!expired && Date.now() >= Date.parse(handle.props.resetsAt)) {
        expire()
        handle.update()
      }
      if (document.visibilityState !== 'visible' || pending || expired) return
      const scope = identity(),
        sequence = ++pollSequence
      try {
        const response = await fetch('/lab/status')
        const data = await response.json()
        if (scope !== identity() || sequence !== pollSequence || expired || pending || handle.signal.aborted)
          return
        if (
          response.status === 409 ||
          response.status === 401 ||
          (data.sandbox && data.sandbox.generation !== handle.props.generation)
        ) {
          expire()
          error = data.error
        } else if (response.ok) {
          story = data.story
          completed = [...new Set([...completed, ...data.completed])]
        }
        if (record) await inspect(record)
        handle.update()
      } catch {
        /* execution remains available; don't pretend refresh succeeded */
      }
    }, 5000)
    handle.signal.addEventListener('abort', () => clearInterval(timer), { once: true })
  }
  return () => {
    if (lastIdentity !== identity()) {
      if (edited) staleDraft = structuredClone(raw())
      lastIdentity = identity()
      inspectionSequence++
      pollSequence++
      story = handle.props.story
      completed = handle.props.completed
      output = null
      record = null
      inspected = null
      error = ''
      initialized = false
      expired = Date.now() >= Date.parse(handle.props.resetsAt)
      pending = false
      activeStep = handle.props.initialStep ?? ''
      const step = story.steps.find((s) => s.id === activeStep)
      if (step) adopt(step, false)
      else
        choose(
          handle.props.initialOperation ?? (handle.props.surface === 'mcp' ? 'gql_whoami' : 'listPeople'),
          false,
        )
    }
    const p = handle.props,
      item = catalog(),
      enhanced = typeof window !== 'undefined'
    const found = p.catalog.filter(
      (op) =>
        op.name === selected ||
        `${op.name} ${op.description} ${op.path ?? ''}`.toLowerCase().includes(query.toLowerCase()),
    )
    const principal = (p.viewer as any)?.data?.viewer ?? (p.viewer as any)
    const permissions: string[] = principal?.permissions ?? []
    return (
      <div class="workbench">
        <dialog
          class="draft-recovery"
          aria-labelledby="draft-recovery-title"
          mix={ref((node: HTMLDialogElement) => {
            recoveryDialog = node
          })}
        >
          <h2 id="draft-recovery-title">Keep your unfinished inputs</h2>
          <p>Some drafts cannot be recovered after leaving. Copy them now, or discard them to continue.</p>
          <p role="status">{notice}</p>
          <button
            class="lab-secondary"
            type="button"
            mix={on('click', async () => {
              try {
                await navigator.clipboard.writeText(
                  JSON.stringify(
                    drafts.unrecovered().map((d) => ({ fields: d.fields, command: d.command })),
                    null,
                    2,
                  ),
                )
                notice = 'Unfinished inputs copied.'
              } catch {
                notice = 'Copy failed. Stay here and select your input to copy it manually.'
              }
              handle.update()
            })}
          >
            Copy unfinished inputs
          </button>
          <button
            class="lab-secondary"
            type="button"
            mix={on('click', () => {
              recoveryDialog?.close()
              leave = undefined
            })}
          >
            Stay here
          </button>
          <button
            class="lab-primary"
            type="button"
            mix={on('click', () => {
              drafts.discardUnrecovered()
              edited = false
              recoveryDialog?.close()
              leave?.()
              leave = undefined
            })}
          >
            Discard and continue
          </button>
        </dialog>
        <div class="workbench-top">
          <div>
            <h1>{p.surface.toUpperCase()} lab</h1>
          </div>
          <nav class="surface-tabs" aria-label="Switch interface">
            {(['mcp', 'api', 'cli'] as Surface[]).map((surface) => (
              <form method="post" action="/lab" key={surface}>
                <input type="hidden" name="intent" value="switch-interface" />
                <input type="hidden" name="surface" value={surface} />
                <input type="hidden" name="mode" value={p.mode} />
                <button
                  type="submit"
                  aria-current={surface === p.surface ? 'page' : undefined}
                  disabled={pending || expired}
                  class={surface === p.surface ? 'selected' : ''}
                >
                  {surface.toUpperCase()}
                </button>
              </form>
            ))}
          </nav>
        </div>
        {expired ? (
          <div role="alert" class="lab-error">
            The shared workspace refreshed. Your input is available for copying.{' '}
            <button
              class="text-button"
              type="button"
              mix={on('click', () => {
                void copy(pretty(raw()))
              })}
            >
              Copy input
            </button>{' '}
            <span role="status">{copyNotice}</span>{' '}
            <a href={`/session?surface=${p.surface}&mode=${p.mode}`}>Choose a persona and start again →</a>
          </div>
        ) : null}
        <div class="bench-grid">
          <aside class="story-panel">
            {p.surface !== 'cli' && p.surface !== 'ui' ? (
              <details
                key="operation-selector"
                class="operation-selector"
                open
                mix={ref((node: HTMLDetailsElement, signal) => {
                  const wide = matchMedia('(min-width: 901px)')
                  const sync = () => {
                    node.open = wide.matches
                  }
                  sync()
                  wide.addEventListener('change', sync, { signal })
                })}
              >
                <summary>
                  {p.surface === 'mcp' ? 'Tool' : 'Request'}: <code>{selected}</code>
                </summary>{' '}
                <label class="bench-label" for="catalog-search">
                  Find a {p.surface === 'mcp' ? 'tool' : 'request'}
                </label>
                <input
                  id="catalog-search"
                  type="search"
                  placeholder="Search by name or capability…"
                  disabled={pending || expired}
                  value={query}
                  mix={on('input', (e) => {
                    query = (e.target as HTMLInputElement).value
                    handle.update()
                  })}
                />
                <label class="bench-label" for="operation">
                  {found.length} operations · pick one
                </label>
                <select
                  id="operation"
                  disabled={pending || expired}
                  value={selected}
                  mix={on('change', (e) => choose((e.target as HTMLSelectElement).value))}
                >
                  {found.map((op) => (
                    <option key={op.name} value={op.name}>
                      {op.name}
                      {!op.available ? ' · unavailable in demo' : ''}
                    </option>
                  ))}
                </select>
              </details>
            ) : null}
            <details
              key="story-guide"
              class="story-guide"
              mix={ref((node: HTMLDetailsElement, signal) => {
                const wide = matchMedia('(min-width: 901px)')
                const sync = () => {
                  node.open = wide.matches
                }
                sync()
                wide.addEventListener('change', sync, { signal })
              })}
            >
              <summary>Suggested experiments</summary>

              <ol class="story-steps">
                {story.steps.map((step, i) => {
                  const permitted = !step.permission || permissions.includes(step.permission)
                  return (
                    <li key={step.id}>
                      <button
                        class={step.id === activeStep ? 'story-step selected' : 'story-step'}
                        type="button"
                        disabled={pending || expired || !permitted}
                        mix={on('click', () => adopt(step))}
                      >
                        <span class={completed.includes(step.id) ? 'step-index done' : 'step-index'}>
                          {completed.includes(step.id) ? '✓' : String(i + 1).padStart(2, '0')}
                        </span>
                        <span>
                          <strong>{step.title}</strong>
                          {!permitted ? (
                            <small class="permission-hint">
                              Needs {step.permission} · try another persona
                            </small>
                          ) : null}
                        </span>
                      </button>
                      {step.surface && p.mode === 'connect' && step.surface !== p.surface ? (
                        <a
                          class="step-link"
                          href={`/lab?surface=${step.surface}&mode=connect&step=${step.id}`}
                        >
                          Continue in {step.surface.toUpperCase()} →
                        </a>
                      ) : step.ui && p.surface === 'ui' ? (
                        <a
                          class="step-link"
                          href={`${step.ui}${step.ui.includes('?') ? '&' : '?'}labStep=${step.id}`}
                        >
                          Open in UI →
                        </a>
                      ) : null}
                    </li>
                  )
                })}
              </ol>
              <details key="experiment-about" class="experiment-about">
                <summary>About this experiment</summary>
                <h2>{story.title}</h2>
                <p>{story.intro}</p>
                <dl>
                  {story.steps.map((step) => (
                    <div key={step.id}>
                      <dt>{step.title}</dt>
                      <dd>{step.detail}</dd>
                    </div>
                  ))}
                </dl>
                <a href="/docs/start">How to play ↗</a>
                {p.surface === 'mcp' ? (
                  <p class="lab-note">Live MCP tools today. Conversational agent in V2.</p>
                ) : null}
              </details>
              <details key="permissions" class="scope-inspector">
                <summary>Your effective permissions</summary>
                <p>
                  {principal?.roleKey ?? principal?.membership?.role_key ?? principal?.role_key ?? 'Member'} ·{' '}
                  {principal?.actorType ?? principal?.actor_type ?? 'user'}
                  {principal?.agent ? ` · ${principal.agent.name}` : ''}
                </p>
                <pre tabIndex={0} role="region" aria-label="Effective permissions">
                  {permissions.join('\n')}
                </pre>
                <details>
                  <summary>Role, scopes, and membership boundary</summary>
                  <pre>
                    {pretty({
                      rolePermissions: principal?.role_permissions,
                      credentialScopes: principal?.credential_scopes,
                      agentScopes: principal?.agent_scopes,
                      membershipScope: principal?.membership_scope,
                    })}
                  </pre>
                </details>
                <a href="/docs/agents">How agent scopes work →</a>
              </details>
            </details>
          </aside>
          <section class="execution-panel" aria-label="Execution area">
            {p.surface === 'ui' ? (
              <div class="ui-launch">
                <h2>Recruiting workspace</h2>
                <p>
                  The same recruiting application, with your selected persona’s permissions and this sandbox’s
                  records.
                </p>
                <a class="lab-primary" href="/today">
                  Open recruiting workspace →
                </a>
                <div class="ui-link-grid">
                  <a href="/people">People ↗</a>
                  <a href="/jobs">Jobs ↗</a>
                  <a href="/pools">Talent pools ↗</a>
                  <a href="/interviews">Interviews ↗</a>
                  <a href="/offers">Offers ↗</a>
                </div>
              </div>
            ) : (
              <>
                {p.surface !== 'cli' ? (
                  <>
                    <div class="operation-heading">
                      <span class={item?.write ? 'method write' : 'method'}>
                        {item?.method ?? (item?.write ? 'WRITE' : 'READ')}
                      </span>
                      <code>{item?.path ?? selected}</code>
                    </div>
                    <p class="operation-description">{item?.description}</p>
                    <form
                      mix={on('submit', (e) => {
                        e.preventDefault()
                        void execute()
                      })}
                    >
                      <div class="argument-fields">
                        {Object.entries(item?.inputSchema.properties ?? {}).map(([key, schema]) => (
                          <label class="argument-field" key={`${selected}-${key}`}>
                            <span>
                              {key}{' '}
                              {(item?.inputSchema.required ?? []).includes(key) ? <strong>*</strong> : null}
                              <small>{schema.description ?? schema.type}</small>
                            </span>
                            {key === 'body' || schema.type === 'object' || schema.type === 'array' ? (
                              <textarea
                                disabled={pending || expired}
                                spellCheck={false}
                                rows={key === 'body' ? 8 : 4}
                                value={String(args[key] ?? '{}')}
                                mix={on('input', (e) => {
                                  args = { ...args, [key]: (e.target as HTMLTextAreaElement).value }
                                  edit()
                                })}
                              />
                            ) : schema.enum ? (
                              <select
                                disabled={pending || expired}
                                value={String(args[key] ?? schema.enum[0])}
                                mix={on('change', (e) => {
                                  args = { ...args, [key]: (e.target as HTMLSelectElement).value }
                                  edit()
                                })}
                              >
                                {schema.enum.map((value) => (
                                  <option key={value} value={value}>
                                    {value}
                                  </option>
                                ))}
                              </select>
                            ) : (
                              <input
                                type="text"
                                disabled={pending || expired}
                                inputMode={
                                  schema.type === 'integer' || schema.type === 'number' ? 'numeric' : 'text'
                                }
                                value={String(args[key] ?? '')}
                                placeholder={
                                  schema.type === 'boolean'
                                    ? 'true / false'
                                    : schema.type === 'string'
                                      ? 'Enter a value…'
                                      : ''
                                }
                                mix={on('input', (e) => {
                                  args = { ...args, [key]: (e.target as HTMLInputElement).value }
                                  edit()
                                })}
                              />
                            )}
                          </label>
                        ))}
                      </div>
                      <div class="run-row">
                        <button
                          class="lab-primary"
                          type="submit"
                          disabled={!enhanced || expired || item?.available === false}
                          aria-disabled={pending ? 'true' : undefined}
                        >
                          {pending ? 'Running…' : p.surface === 'mcp' ? 'Run tool →' : 'Send request →'}
                        </button>
                        <span role="status">{requestStatus}</span>
                        {output ? (
                          <a class="response-link" href="#lab-response">
                            View response ↓
                          </a>
                        ) : null}
                      </div>
                    </form>
                  </>
                ) : (
                  <>
                    <div class="terminal">
                      <p class="lab-note">Commands use an isolated demo directory. No system shell.</p>
                      <form
                        mix={on('submit', (e) => {
                          e.preventDefault()
                          void execute()
                        })}
                      >
                        <label for="cli-command" class="bench-label">
                          Command
                        </label>
                        <textarea
                          id="cli-command"
                          rows={4}
                          disabled={pending || expired}
                          spellCheck={false}
                          value={command}
                          mix={on('input', (e) => {
                            command = (e.target as HTMLTextAreaElement).value
                            edit()
                          })}
                        />
                        <div class="run-row">
                          <button
                            class="lab-primary"
                            type="submit"
                            disabled={!enhanced || expired}
                            aria-disabled={pending ? 'true' : undefined}
                          >
                            {pending ? 'Running…' : 'Run command →'}
                          </button>
                          <span role="status">{requestStatus}</span>
                          {output ? (
                            <a class="response-link" href="#lab-response">
                              View response ↓
                            </a>
                          ) : null}
                        </div>
                      </form>
                      <details class="terminal-suggestions">
                        <summary>Command examples</summary>
                        {[
                          'bigbuck help',
                          'bigbuck whoami',
                          'bigbuck person list',
                          'bigbuck config init --preset recruiting-team',
                        ].map((text) => (
                          <button
                            type="button"
                            key={text}
                            disabled={pending || expired}
                            mix={on('click', () => {
                              command = text
                              edit()
                            })}
                          >
                            {text}
                          </button>
                        ))}
                      </details>
                    </div>
                    {history.length ? (
                      <details class="command-history">
                        <summary>Recent commands</summary>
                        {history.map((text) => (
                          <button
                            type="button"
                            key={text}
                            disabled={pending || expired}
                            mix={on('click', () => {
                              command = text
                              edit()
                            })}
                          >
                            {text}
                          </button>
                        ))}
                      </details>
                    ) : null}
                  </>
                )}
              </>
            )}
            {error ? (
              <p role="alert" class="lab-error">
                {error}
              </p>
            ) : null}
            {output ? (
              <section class="result-panel" id="lab-response" aria-labelledby="lab-response-heading">
                <h2 id="lab-response-heading">Response</h2>
                <p class="lab-note">Response from {origin}</p>
                <div class="result-heading">
                  <span class={output.ok ? 'result-status good' : 'result-status bad'}>
                    {output.status}{' '}
                    {output.outcome === 'unknown' ? 'Outcome unknown' : output.ok ? 'OK' : 'Refused / failed'}
                  </span>
                  <span>{output.duration} ms</span>
                  <button
                    class="text-button"
                    type="button"
                    mix={on('click', () => {
                      void copy(pretty(output!.output))
                    })}
                  >
                    Copy result
                  </button>
                </div>
                {output.request ? <code class="result-request">{output.request}</code> : null}
                <p role="status" class="lab-note">
                  {copyNotice}
                </p>
                <pre tabIndex={0} role="region" aria-label="Response content">
                  {pretty(output.output)}
                </pre>
                {output.example ? (
                  <details>
                    <summary>Copyable request example</summary>
                    <pre tabIndex={0} role="region" aria-label="Request example">
                      {output.example}
                    </pre>
                    <button
                      class="text-button"
                      type="button"
                      mix={on('click', () => {
                        void copy(output!.example!)
                      })}
                    >
                      Copy request
                    </button>
                  </details>
                ) : null}
                <a href={output.ok ? '/docs/interop' : '/docs/permissions'}>How this works ↗</a>
              </section>
            ) : (
              <p class="result-empty">Nothing runs until you choose Run.</p>
            )}
            {p.surface !== 'ui' ? (
              <div class="draft-controls">
                <details key="draft-recovery">
                  <summary>Draft recovery</summary>
                  <label>
                    <input
                      type="checkbox"
                      checked={recover}
                      disabled={pending || expired}
                      mix={on('change', (e) => {
                        recover = (e.target as HTMLInputElement).checked
                        save()
                        handle.update()
                      })}
                    />
                    Remember disposable sample inputs in this tab
                  </label>
                  <p>
                    Use sample data only. Credentials and sensitive input stay in memory. No responses or
                    records are saved.
                  </p>
                  {edited ? (
                    <p>
                      {saved
                        ? 'Draft saved for this persona, sandbox, generation and operation.'
                        : memoryOnly(raw())
                          ? 'Sensitive input detected. Copy it before leaving.'
                          : 'Draft is memory-only. Copy or discard before leaving.'}
                    </p>
                  ) : null}
                </details>
                {activeStep ? (
                  <button
                    class="lab-secondary"
                    type="button"
                    disabled={pending || expired}
                    mix={on('click', () => {
                      const step = story.steps.find((s) => s.id === activeStep)
                      if (step) {
                        loadStep(step)
                        handle.update()
                      }
                    })}
                  >
                    Load step inputs
                  </button>
                ) : null}
              </div>
            ) : null}
            <p class="lab-note" role="status">
              {notice}
            </p>
            {staleDraft ? (
              <details>
                <summary>Input from a previous scope — copy only</summary>
                <p>Review record IDs before using this input in another sandbox or generation.</p>
                <pre tabIndex={0}>{pretty({ fields: staleDraft.fields, command: staleDraft.command })}</pre>
              </details>
            ) : null}
            {p.surface !== 'ui' && p.surface !== 'cli' ? (
              <>
                {' '}
                <details key="schema" class="schema-inspector">
                  <summary>Inspect input schema</summary>
                  <pre tabIndex={0} role="region" aria-label="Input schema">
                    {pretty(item?.bodySchema ?? item?.inputSchema)}
                  </pre>
                </details>
              </>
            ) : null}
          </section>
          <aside class="record-panel">
            {/* Opens on its own once a run returns records, so the UI and JSON links are in view. */}
            <details key="related-records" open={Boolean(output?.links?.length)}>
              <summary>Related records</summary>
              {output?.links?.length ? (
                <div class="record-links">
                  {output.links.map((link) => (
                    <div class="record-link-row" key={link.href}>
                      <button
                        class={record?.id === link.id ? 'record-link selected' : 'record-link'}
                        type="button"
                        mix={on('click', () => {
                          void inspect(link)
                        })}
                      >
                        <span>{link.label}</span>
                        <small>{link.kind}</small>
                      </button>
                      <a
                        class="lab-secondary record-json-link"
                        href={`/lab/inspect?${new URLSearchParams({ kind: link.kind, id: link.id })}`}
                        target="_blank"
                        rel="noopener"
                        aria-label={`Open ${link.label} as JSON`}
                      >
                        JSON ↗
                      </a>
                    </div>
                  ))}
                </div>
              ) : (
                <p>Run a step to list the records it touched. Each opens in the UI or as JSON.</p>
              )}
              {record ? (
                <>
                  <a class="lab-secondary" href={record.href}>
                    Continue in UI →
                  </a>{' '}
                  <a
                    class="lab-secondary"
                    href={`/lab/inspect?${new URLSearchParams({ kind: record.kind, id: record.id })}`}
                    target="_blank"
                    rel="noopener"
                  >
                    Open as JSON ↗
                  </a>
                  <details key={`${record.kind}:${record.id}`}>
                    <summary>Raw record</summary>
                    <pre class="record-json" tabIndex={0} role="region" aria-label="Inspected record">
                      {pretty(inspected)}
                    </pre>
                  </details>
                  <small>Refreshes every five seconds while visible.</small>
                </>
              ) : null}
              <a class="how-link" href="/docs/data-model">
                How the data fits together ↗
              </a>
              {permissions.includes('audit.read') ? (
                <button
                  class="lab-secondary"
                  type="button"
                  mix={on('click', () => {
                    void inspect({
                      kind: 'audit',
                      id:
                        handle.props.sandbox === 'ui'
                          ? '00000000-0000-0000-0000-000000000000'
                          : '00000000-0000-0000-0000-000000000000',
                      label: 'Audit events',
                      href: '/admin',
                    })
                  })}
                >
                  Inspect audit events
                </button>
              ) : (
                <p class="lab-note">
                  Audit history is role-protected.
                  <br />
                  <a href="/docs/audit">See a labeled example →</a>
                </p>
              )}
            </details>
          </aside>
        </div>
      </div>
    )
  }
})
