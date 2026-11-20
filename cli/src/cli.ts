#!/usr/bin/env node
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

import { BigBuckApiError, CURATED_TOOLS, findCuratedTool } from '@bigbuck/sdk'

import { flagBool, flagString, parseArgs } from './args.js'
import { clientFromArgs } from './client.js'
import { initConfigFolder, loadDocumentsFromDir } from './config-files.js'
import { die, printJson, printTable } from './output.js'
import { accessToken, keychainStore, login, logout, serviceTokenProvider, settingsFromEnv, verifyApiIdentity } from './oauth.js'

const HELP = `bigbuck — company setup & recruiter ops CLI

Usage:
  bigbuck <command> [flags]

Auth / context:
  bigbuck auth login   Browser sign-in with OAuth + PKCE; tokens stay in the OS keychain
  bigbuck auth logout  Revoke the provider grant and remove the local session
  bigbuck auth status  Verify the current OAuth identity against the API
  --token <token>       Bearer token (or BIGBUCK_TOKEN)
  --as-agent <id>       Act as one of your agents (or BIGBUCK_ACT_AS_AGENT)
  --org <uuid>          Local header harness only (or BIGBUCK_ORG_ID)
  --actor <uuid>        Acting user (or BIGBUCK_ACTOR_ID)
  --api-url <url>       API origin (default http://127.0.0.1:3000)
  --json                Machine-readable output

Company setup:
  bigbuck whoami
  bigbuck config init --preset recruiting-team|admins-only [--dir ./bigbuck]
  bigbuck config plan [--dir ./bigbuck]
  bigbuck config apply --plan-id <id>
  bigbuck config plans
  bigbuck import csv --file people.csv [--dry-run] [--source-system csv]

Recruiter ops:
  bigbuck person list|show <id>|create --name <n> [--email <e>]
  bigbuck job list|show <id>|create --title <t>
  bigbuck project list|create --name <n>|add <projectId> <personId>|members <projectId>|convert <memberId> [--job <id>]
  bigbuck sequence list|create --key <k> --name <n>|enroll <seqId> <personId> [--mailbox <id>]|stop <enrollmentId>
  bigbuck application list [--job <id>] [--person <id>]|show <id>|create --job <id> --person <id>|move <id> --to <stage>|reject <id> --reason <r>

Agents:
  bigbuck agent list|create --name <n> --scopes <a,b>|credential <agentId> [--name <n>]|pause <id>|resume <id>|revoke <id>

Full OpenAPI surface (same operationIds as MCP REST tools):
  bigbuck api list [--write|--read] [--q <substring>]
  bigbuck api <operationId> [--param=value ...] [--body '<json>']

GraphQL (same curated tools as MCP, plus ad hoc documents):
  bigbuck gql list
  bigbuck gql whoami|person|job-pipeline|custom-fields|move-application|reject-application|set-custom-field
  bigbuck gql query --query '<document>' [--variables '<json>']
`

async function main(): Promise<void> {
  const parsed = parseArgs(process.argv)
  const [group, action, ...rest] = parsed.command
  if (!group || group === 'help' || parsed.flags.help || parsed.flags.h) {
    process.stdout.write(`${HELP}\n`)
    return
  }

  const json = flagBool(parsed.flags, 'json')

  try {
    if (group === 'config' && action === 'init') {
      const preset = flagString(parsed.flags, 'preset') ?? 'recruiting-team'
      const dir = resolve(flagString(parsed.flags, 'dir') ?? './bigbuck')
      const org = flagString(parsed.flags, 'org', 'organization-id')
      initConfigFolder(dir, preset, org)
      if (json) printJson({ dir, preset })
      else process.stdout.write(`Initialized ${dir} from preset ${preset}\n`)
      return
    }

    const explicitToken = flagString(parsed.flags, 'token') ?? process.env.BIGBUCK_TOKEN
    const oauthConfigured = !!process.env.BIGBUCK_OAUTH_ISSUER
    let tokenProvider: (() => Promise<string>) | undefined
    if (group === 'auth' || (oauthConfigured && !explicitToken)) {
      const settings = settingsFromEnv(flagString(parsed.flags, 'api-url'))
      if (process.env.BIGBUCK_OAUTH_CLIENT_SECRET) {
        if (group === 'auth' && action !== 'status') throw new Error('Service identities use client credentials; browser login/logout is for human clients')
        tokenProvider = serviceTokenProvider(settings, process.env.BIGBUCK_OAUTH_CLIENT_SECRET)
      } else {
        const store = await keychainStore(settings)
        if (group === 'auth' && action === 'login') {
          const identity = await login(settings, store)
          if (json) printJson(identity)
          else process.stdout.write('Signed in. Tokens are stored in your OS keychain.\n')
          return
        }
        if (group === 'auth' && action === 'logout') {
          await logout(settings, store)
          if (json) printJson({ signed_out: true })
          else process.stdout.write('Signed out and removed the local session.\n')
          return
        }
        tokenProvider = () => accessToken(settings, store)
      }
      if (group === 'auth') {
        if (action !== 'status') throw new Error('auth: use login | logout | status')
        printJson(await verifyApiIdentity(settings, await tokenProvider()))
        return
      }
    }
    const client = clientFromArgs(parsed, tokenProvider)

    if (group === 'whoami') {
      const health = await client.getHealth()
      const session = client.token || tokenProvider ? ((await client.currentSession()) as Record<string, any>) : null
      const payload = {
        organization_id: session?.organization_id ?? client.organizationId ?? null,
        actor_type: session?.actor_type ?? null,
        actor_id: session?.agent?.id ?? session?.user?.id ?? client.actorId ?? null,
        user: session?.user ?? null,
        agent: session?.agent ?? null,
        api: client.baseUrl,
        health,
      }
      if (json) printJson(payload)
      else {
        process.stdout.write(`org=${payload.organization_id ?? '(none)'}\n`)
        process.stdout.write(`actor=${payload.actor_type ?? 'legacy'}:${payload.actor_id ?? '(none)'}\n`)
        process.stdout.write(`api=${payload.api}\n`)
        process.stdout.write(`health=${health.status} (${health.service})\n`)
      }
      return
    }

    if (group === 'config') {
      await runConfig(client, action, parsed, json)
      return
    }
    if (group === 'import') {
      await runImport(client, action, parsed, json)
      return
    }
    if (group === 'person') {
      await runPerson(client, action, rest, parsed, json)
      return
    }
    if (group === 'job') {
      await runJob(client, action, rest, parsed, json)
      return
    }
    if (group === 'project') {
      await runProject(client, action, rest, parsed, json)
      return
    }
    if (group === 'sequence') {
      await runSequence(client, action, rest, parsed, json)
      return
    }
    if (group === 'application') {
      await runApplication(client, action, rest, parsed, json)
      return
    }
    if (group === 'agent') {
      await runAgent(client, action, rest, parsed, json)
      return
    }
    if (group === 'api') {
      await runApi(client, action, rest, parsed, json)
      return
    }
    if (group === 'gql' || group === 'graphql') {
      await runGraphql(client, action, rest, parsed, json)
      return
    }

    die(`Unknown command: ${parsed.command.join(' ')}\n\n${HELP}`)
  } catch (error) {
    if (error instanceof BigBuckApiError) {
      if (json) printJson({ error: error.problem })
      else {
        process.stderr.write(`Error ${error.status}${error.code ? ` [${error.code}]` : ''}: ${error.message}\n`)
        if (error.requestId) process.stderr.write(`request_id=${error.requestId}\n`)
      }
      process.exit(1)
    }
    die(error instanceof Error ? error.message : String(error))
  }
}

async function runConfig(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'plans') {
    const res = await client.listConfigPlans()
    if (json) printJson(res)
    else printTable(res.data, ['id', 'status', 'created_at'])
    return
  }
  if (action === 'plan') {
    const dir = resolve(flagString(parsed.flags, 'dir') ?? './bigbuck')
    const documents = loadDocumentsFromDir(dir)
    if (!documents.length) die(`No config documents found in ${dir}`)
    const plan = await client.createConfigPlan(documents)
    if (json) printJson(plan)
    else {
      process.stdout.write(`plan ${plan.id} status=${plan.status}\n`)
      process.stdout.write(`documents=${documents.length}\n`)
    }
    return
  }
  if (action === 'apply') {
    const planId = flagString(parsed.flags, 'plan-id', 'plan')
    if (!planId) die('config apply requires --plan-id')
    const result = await client.applyConfigPlan(planId)
    if (json) printJson(result)
    else process.stdout.write(`applied plan ${planId} status=${(result.plan as { status?: string })?.status}\n`)
    return
  }
  die('config: use init | plan | apply | plans')
}

async function runImport(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action !== 'csv') die('import: use csv')
  const file = flagString(parsed.flags, 'file', 'f')
  if (!file) die('import csv requires --file')
  const csv = readFileSync(resolve(file), 'utf8')
  const mappingRaw = flagString(parsed.flags, 'map')
  const fieldMapping = mappingRaw
    ? Object.fromEntries(
        mappingRaw.split(',').map((pair) => {
          const [from, to] = pair.split('=')
          return [from.trim(), to.trim()]
        }),
      )
    : undefined
  const run = await client.createImport({
    csv,
    dryRun: flagBool(parsed.flags, 'dry-run'),
    sourceSystem: flagString(parsed.flags, 'source-system') ?? 'csv',
    fieldMapping,
  })
  if (json) printJson(run)
  else {
    process.stdout.write(
      `import ${run.id} status=${run.status} rows=${run.row_count} created=${run.created_count} updated=${run.updated_count} errors=${run.error_count}\n`,
    )
  }
}

async function runPerson(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'list') {
    const res = await client.listPeople()
    if (json) printJson(res)
    else printTable(res.data, ['id', 'display_name', 'primary_email', 'lifecycle_stage'])
    return
  }
  if (action === 'show') {
    const id = rest[0] ?? parsed.positionals[0]
    if (!id) die('person show <id>')
    const person = await client.getPerson(id)
    if (json) printJson(person)
    else printJson(person)
    return
  }
  if (action === 'create') {
    const name = flagString(parsed.flags, 'name', 'n')
    if (!name) die('person create requires --name')
    const person = await client.createPerson({
      display_name: name,
      email: flagString(parsed.flags, 'email'),
      phone: flagString(parsed.flags, 'phone'),
    })
    if (json) printJson(person)
    else process.stdout.write(`${person.id}  ${person.display_name}\n`)
    return
  }
  die('person: use list | show | create')
}

async function runJob(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'list') {
    const res = await client.listJobs()
    if (json) printJson(res)
    else printTable(res.data, ['id', 'title', 'status'])
    return
  }
  if (action === 'show') {
    const id = rest[0]
    if (!id) die('job show <id>')
    printJson(await client.getJob(id))
    return
  }
  if (action === 'create') {
    const title = flagString(parsed.flags, 'title', 't')
    if (!title) die('job create requires --title')
    const job = await client.createJob({ title, status: flagString(parsed.flags, 'status') })
    if (json) printJson(job)
    else process.stdout.write(`${job.id}  ${job.title}\n`)
    return
  }
  die('job: use list | show | create')
}

async function runProject(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'list') {
    const res = await client.listProjects()
    if (json) printJson(res)
    else printTable(res.data, ['id', 'name', 'job_id'])
    return
  }
  if (action === 'create') {
    const name = flagString(parsed.flags, 'name', 'n')
    if (!name) die('project create requires --name')
    const project = await client.createProject({
      name,
      job_id: flagString(parsed.flags, 'job', 'job-id'),
    })
    if (json) printJson(project)
    else process.stdout.write(`${project.id}  ${project.name}\n`)
    return
  }
  if (action === 'members') {
    const projectId = rest[0]
    if (!projectId) die('project members <projectId>')
    const res = await client.listProjectMembers(projectId)
    if (json) printJson(res)
    else printTable(res.data, ['id', 'person_id', 'status', 'current_stage_key'])
    return
  }
  if (action === 'add') {
    const [projectId, personId] = rest
    if (!projectId || !personId) die('project add <projectId> <personId>')
    const member = await client.addProjectMember(projectId, personId)
    if (json) printJson(member)
    else process.stdout.write(`${member.id}  person=${member.person_id}\n`)
    return
  }
  if (action === 'convert') {
    const memberId = rest[0]
    if (!memberId) die('project convert <memberId> [--job <id>]')
    const result = await client.convertProjectMember(memberId, flagString(parsed.flags, 'job', 'job-id'))
    printJson(result)
    return
  }
  die('project: use list | create | members | add | convert')
}

async function runSequence(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'list') {
    const res = await client.listSequences()
    if (json) printJson(res)
    else printTable(res.data, ['id', 'key', 'name', 'status', 'enrollment_count'])
    return
  }
  if (action === 'create') {
    const key = flagString(parsed.flags, 'key')
    const name = flagString(parsed.flags, 'name', 'n')
    if (!key || !name) die('sequence create requires --key and --name')
    const seq = await client.createSequence({ key, name })
    if (json) printJson(seq)
    else process.stdout.write(`${seq.id}  ${seq.key}\n`)
    return
  }
  if (action === 'enroll') {
    const [sequenceId, personId] = rest
    if (!sequenceId || !personId) die('sequence enroll <sequenceId> <personId> [--mailbox <id>]')
    const enrollment = await client.enrollInSequence(
      sequenceId,
      personId,
      flagString(parsed.flags, 'mailbox', 'mailbox-id'),
    )
    if (json) printJson(enrollment)
    else process.stdout.write(`${enrollment.id}  status=${enrollment.status}\n`)
    return
  }
  if (action === 'stop') {
    const enrollmentId = rest[0]
    if (!enrollmentId) die('sequence stop <enrollmentId>')
    const enrollment = await client.stopEnrollment(enrollmentId)
    if (json) printJson(enrollment)
    else process.stdout.write(`${enrollment.id}  status=${enrollment.status}\n`)
    return
  }
  die('sequence: use list | create | enroll | stop')
}

async function runApplication(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'list') {
    const res = await client.listApplications({
      jobId: flagString(parsed.flags, 'job', 'job-id'),
      personId: flagString(parsed.flags, 'person', 'person-id'),
    })
    if (json) printJson(res)
    else printTable(res.data, ['id', 'job_id', 'person_id', 'status', 'current_stage_key'])
    return
  }
  if (action === 'show') {
    const id = rest[0]
    if (!id) die('application show <id>')
    printJson(await client.getApplication(id))
    return
  }
  if (action === 'create') {
    const jobId = flagString(parsed.flags, 'job', 'job-id')
    const personId = flagString(parsed.flags, 'person', 'person-id')
    if (!jobId || !personId) die('application create requires --job and --person')
    const app = await client.createApplication({ job_id: jobId, person_id: personId })
    if (json) printJson(app)
    else process.stdout.write(`${app.id}  stage=${app.current_stage_key}\n`)
    return
  }
  if (action === 'move') {
    const id = rest[0]
    const to = flagString(parsed.flags, 'to', 'stage')
    if (!id || !to) die('application move <id> --to <stage-key>')
    const app = await client.moveApplication(id, to, flagString(parsed.flags, 'reason'))
    if (json) printJson(app)
    else process.stdout.write(`${app.id}  stage=${app.current_stage_key}\n`)
    return
  }
  if (action === 'reject') {
    const id = rest[0]
    const reason = flagString(parsed.flags, 'reason', 'r')
    if (!id || !reason) die('application reject <id> --reason <reason>')
    const app = await client.rejectApplication(id, reason)
    if (json) printJson(app)
    else process.stdout.write(`${app.id}  status=${app.status}\n`)
    return
  }
  die('application: use list | show | create | move | reject')
}

async function runAgent(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (action === 'list') {
    const res = await client.listAgents()
    if (json) printJson(res)
    else printTable(res.data, ['id', 'name', 'status'])
    return
  }
  if (action === 'create') {
    const name = flagString(parsed.flags, 'name', 'n')
    const scopesRaw = flagString(parsed.flags, 'scopes')
    if (!name || !scopesRaw) die('agent create requires --name and --scopes (comma-separated)')
    const scopes = scopesRaw.split(',').map((scope) => scope.trim()).filter(Boolean)
    const agent = await client.createAgent({
      name,
      scopes,
      description: flagString(parsed.flags, 'description'),
    })
    if (json) printJson(agent)
    else process.stdout.write(`${agent.id}  ${agent.name}\n`)
    return
  }
  if (action === 'credential') {
    const agentId = rest[0]
    if (!agentId) die('agent credential <agentId> [--name <n>] [--expires-at <iso>]')
    const credential = await client.createAgentCredential(agentId, {
      name: flagString(parsed.flags, 'name', 'n'),
      expires_at: flagString(parsed.flags, 'expires-at'),
    })
    printJson(credential)
    return
  }
  if (action === 'pause' || action === 'resume' || action === 'revoke') {
    const agentId = rest[0]
    if (!agentId) die(`agent ${action} <agentId>`)
    const result =
      action === 'pause'
        ? await client.pauseAgent(agentId)
        : action === 'resume'
          ? await client.resumeAgent(agentId)
          : await client.revokeAgent(agentId)
    if (json) printJson(result)
    else process.stdout.write(`${result.id}  status=${result.status}\n`)
    return
  }
  die('agent: use list | create | credential | pause | resume | revoke')
}

async function runApi(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (!action || action === 'help') die(`api: use list | <operationId>\n\n${HELP}`)
  if (action === 'list') {
    const q = (flagString(parsed.flags, 'q') ?? '').toLowerCase()
    const writeOnly = flagBool(parsed.flags, 'write')
    const readOnly = flagBool(parsed.flags, 'read')
    const rows = client
      .listOperations()
      .filter((op) => (!q || op.operationId.toLowerCase().includes(q) || (op.summary ?? '').toLowerCase().includes(q)))
      .filter((op) => (writeOnly ? op.write : true))
      .filter((op) => (readOnly ? !op.write : true))
      .map((op) => ({
        operationId: op.operationId,
        method: op.method.toUpperCase(),
        path: op.path,
        write: op.write ? 'yes' : '',
        summary: op.summary ?? '',
      }))
    if (json) printJson({ data: rows })
    else printTable(rows, ['operationId', 'method', 'path', 'write'])
    return
  }

  const operationId = action
  const args: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(parsed.flags)) {
    if (['json', 'token', 'as-agent', 'org', 'organization-id', 'actor', 'actor-id', 'api-url', 'write', 'read', 'help', 'h'].includes(key)) {
      continue
    }
    if (key === 'body') {
      if (typeof value !== 'string') die('api --body requires a JSON string')
      try {
        args.body = JSON.parse(value)
      } catch {
        die('api --body must be valid JSON')
      }
      continue
    }
    args[key.replaceAll('-', '_')] = value
  }
  // Positional leftovers become path `id` when the operation needs one and none was provided.
  if (rest[0] && args.id === undefined) args.id = rest[0]

  const result = await client.invoke(operationId, args)
  if (json || typeof result === 'object') printJson(result)
  else process.stdout.write(`${String(result)}\n`)
}

const GQL_ALIASES: Record<string, string> = {
  whoami: 'gql_whoami',
  person: 'gql_person',
  'job-pipeline': 'gql_job_pipeline',
  pipeline: 'gql_job_pipeline',
  'custom-fields': 'gql_custom_field_definitions',
  fields: 'gql_custom_field_definitions',
  'move-application': 'gql_move_application_stage',
  move: 'gql_move_application_stage',
  'reject-application': 'gql_reject_application',
  reject: 'gql_reject_application',
  'set-custom-field': 'gql_set_custom_field_value',
  'set-field': 'gql_set_custom_field_value',
}

async function runGraphql(
  client: ReturnType<typeof clientFromArgs>,
  action: string | undefined,
  rest: string[],
  parsed: ReturnType<typeof parseArgs>,
  json: boolean,
): Promise<void> {
  if (!action || action === 'help') die(`gql: use list | whoami | person | query | …\n\n${HELP}`)
  if (action === 'list') {
    const rows = CURATED_TOOLS.map((tool) => ({
      name: tool.name,
      write: tool.write ? 'yes' : '',
      description: tool.description,
    }))
    if (json) printJson({ data: rows })
    else printTable(rows, ['name', 'write', 'description'])
    return
  }
  if (action === 'query') {
    const document = flagString(parsed.flags, 'query') ?? rest[0]
    if (!document) die('gql query requires --query \'<document>\'')
    const rawVars = flagString(parsed.flags, 'variables', 'vars')
    let variables: Record<string, unknown> = {}
    if (rawVars) {
      try {
        variables = JSON.parse(rawVars) as Record<string, unknown>
      } catch {
        die('gql --variables must be valid JSON')
      }
    }
    printJson(await client.graphql(document, variables))
    return
  }

  const toolName = GQL_ALIASES[action] ?? (action.startsWith('gql_') ? action : undefined)
  if (!toolName || !findCuratedTool(toolName)) {
    die(`Unknown GraphQL command: ${action}\n\n${HELP}`)
  }

  const variables: Record<string, unknown> = {}
  const tool = findCuratedTool(toolName)!
  for (const [key, value] of Object.entries(parsed.flags)) {
    if (
      [
        'json',
        'token',
        'as-agent',
        'org',
        'organization-id',
        'actor',
        'actor-id',
        'api-url',
        'query',
        'variables',
        'vars',
        'help',
        'h',
      ].includes(key)
    ) {
      continue
    }
    const name = key === 'expected-version' ? 'expectedVersion' : key === 'entity-type' ? 'entityType' : key === 'entity-id' ? 'entityId' : key.replaceAll('-', '_')
    if (name === 'value' && typeof value === 'string') {
      try {
        variables.value = JSON.parse(value)
      } catch {
        die('gql --value must be valid JSON')
      }
      continue
    }
    variables[name] = value
  }
  if (rest[0] && variables.id === undefined && tool.variables.id) variables.id = rest[0]
  if (rest[0] && variables.entity === undefined && tool.variables.entity) variables.entity = rest[0]

  printJson(await client.curatedGraphql(toolName, variables))
}

main()
