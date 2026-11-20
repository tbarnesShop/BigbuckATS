import { createController } from 'remix/router'

import { actAsAgent, signedIn } from '../../data/auth.ts'
import {
  agentCommand,
  createAgent,
  createPersonalToken,
  issueAgentToken,
  listAgents,
  listCredentials,
  revokeCredential,
  sessionFromRequest,
  type ApiHeaders,
} from '../../data/api.ts'
import { gql } from '../../data/graphql.ts'
import { ALL_SCOPE_KEYS } from '../../data/scopes.ts'
import { refreshViewer } from '../../data/viewer.ts'
import type {
  ArchiveCustomFieldMutation,
  CreateCustomFieldMutation,
  CustomFieldDefinitionsQuery,
} from '../../graphql/generated.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { AgentsPage, FIELD_ENTITIES, FieldsPage, KeysPage } from './pages.tsx'

function scopesFrom(form: FormData): string[] {
  return form.getAll('scopes').map(String).filter((s) => ALL_SCOPE_KEYS.includes(s))
}

function message(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

/** Identity changes are made as the person, never as an agent they are acting as. */
function asPerson(session: ApiHeaders): ApiHeaders {
  return { token: session.token }
}

export const agentsController = createController(routes.settingsAgents, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const { data } = await listAgents(asPerson(session))
      return context.render(<AgentsPage agents={data} actingAgentId={signedIn()?.actingAgentId} />)
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const person = asPerson(session)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      const agentId = String(form.get('agent_id') ?? '')
      const agentName = String(form.get('agent_name') ?? '')
      let notice: string | undefined
      let error: string | undefined
      let token: string | undefined
      try {
        if (intent === 'create') {
          const scopes = scopesFrom(form)
          if (scopes.length === 0) throw new Error('Pick at least one scope')
          const agent = await createAgent(person, {
            name: String(form.get('name') ?? '').trim(),
            description: String(form.get('description') ?? '').trim() || undefined,
            scopes,
          })
          notice = `Created ${agent.name}`
        } else if (intent === 'issue-token') {
          token = (await issueAgentToken(person, agentId, `${agentName} token`)).token
          notice = `New token for ${agentName}`
        } else if (intent === 'pause' || intent === 'resume' || intent === 'revoke') {
          await agentCommand(person, agentId, intent)
          if (intent !== 'resume' && signedIn()?.actingAgentId === agentId) actAsAgent(null)
          notice = `${agentName} ${intent === 'pause' ? 'paused' : intent === 'resume' ? 'resumed' : 'revoked'}`
        } else if (intent === 'act-as') {
          actAsAgent({ id: agentId, name: agentName })
          const viewer = await refreshViewer({ token: session.token, actingAgentId: agentId })
          if (!viewer?.agent) {
            actAsAgent(null)
            await refreshViewer(person)
            throw new Error(`Could not act as ${agentName}`)
          }
          notice = `Acting as ${agentName}. Your actions are recorded as the agent's.`
        } else if (intent === 'stop-acting') {
          actAsAgent(null)
          await refreshViewer(person)
          notice = 'Back to acting as yourself'
        }
      } catch (e) {
        error = message(e)
      }
      const { data } = await listAgents(person)
      return context.render(
        <AgentsPage agents={data} actingAgentId={signedIn()?.actingAgentId} token={token} notice={notice} error={error} />,
      )
    },
  },
})

export const keysController = createController(routes.settingsKeys, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const { data } = await listCredentials(asPerson(session))
      return context.render(<KeysPage credentials={data} />)
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const person = asPerson(session)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      let notice: string | undefined
      let error: string | undefined
      let token: string | undefined
      try {
        if (intent === 'create') {
          const scopes = scopesFrom(form)
          if (scopes.length === 0) throw new Error('Pick at least one scope')
          const created = await createPersonalToken(person, { name: String(form.get('name') ?? '').trim(), scopes })
          token = created.token
          notice = `Created ${created.name}`
        } else if (intent === 'revoke') {
          const revoked = await revokeCredential(person, String(form.get('credential_id') ?? ''))
          notice = `Revoked ${revoked.name}`
        }
      } catch (e) {
        error = message(e)
      }
      const { data } = await listCredentials(person)
      return context.render(<KeysPage credentials={data} token={token} notice={notice} error={error} />)
    },
  },
})

function entityFrom(url: URL): string {
  const entity = url.searchParams.get('entity') ?? 'person'
  return (FIELD_ENTITIES as readonly string[]).includes(entity) ? entity : 'person'
}

async function loadFields(session: ApiHeaders, entity: string) {
  const data = await gql<CustomFieldDefinitionsQuery, { entity: string }>(session, 'CustomFieldDefinitions', { entity })
  return data.customFieldDefinitions
}

export const fieldsController = createController(routes.settingsFields, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const entity = entityFrom(context.url)
      try {
        return context.render(<FieldsPage entity={entity} fields={await loadFields(session, entity)} />)
      } catch (e) {
        return context.render(<FieldsPage entity={entity} fields={[]} error={message(e)} />)
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const entity = entityFrom(context.url)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      let notice: string | undefined
      let error: string | undefined
      try {
        if (intent === 'create') {
          const options = String(form.get('options') ?? '')
            .split(',')
            .map((o) => o.trim())
            .filter(Boolean)
            .map((label) => ({ key: label.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, ''), label }))
          const result = await gql<CreateCustomFieldMutation, Record<string, unknown>>(session, 'CreateCustomField', {
            entity,
            key: String(form.get('key') ?? '').trim(),
            label: String(form.get('label') ?? '').trim(),
            fieldType: String(form.get('field_type') ?? 'text'),
            dataClass: String(form.get('data_class') ?? 'internal'),
            options: options.length ? options : undefined,
          })
          const problem = result.createCustomField?.userErrors[0]
          if (problem) throw new Error(problem.message)
          notice = `Added ${result.createCustomField?.field?.key}`
        } else if (intent === 'archive' || intent === 'restore') {
          const result = await gql<ArchiveCustomFieldMutation, Record<string, unknown>>(session, 'ArchiveCustomField', {
            id: String(form.get('field_id') ?? ''),
            restore: intent === 'restore',
            expectedVersion: Number(form.get('expected_version') ?? 0) || undefined,
          })
          const problem = result.archiveCustomField?.userErrors[0]
          if (problem) throw new Error(problem.message)
          notice = intent === 'archive' ? 'Field archived; its values are kept' : 'Field restored'
        }
      } catch (e) {
        error = message(e)
      }
      const fields = await loadFields(session, entity).catch(() => [])
      return context.render(<FieldsPage entity={entity} fields={fields} notice={notice} error={error} />)
    },
  },
})
