import { sealData, unsealData } from 'iron-session'
import { createCookie } from 'remix/cookie'
import { getContext } from 'remix/middleware/async-context'
import { createCookieSessionStorage } from 'remix/session-storage/cookie'
import { readLabCredentials, storeLabCredentials } from './lab/credentials.ts'

/**
 * Browser identity lives in a signed, HTTP-only cookie holding the Rails session
 * token. Nothing about who you are travels in URLs. The token is only ever sent
 * server-to-server to Rails as `Authorization: Bearer`.
 */

const SESSION_SECONDS = 12 * 60 * 60

function sessionSecret(): string {
  const secret = process.env.SESSION_SECRET
  if (secret && secret.length >= 32) return secret
  if (process.env.NODE_ENV === 'production') {
    throw new Error('SESSION_SECRET is required in production')
  }
  return 'bigbuck-dev-only-session-secret-padding'
}

export const sessionCookie = createCookie('__bigbuck', {
  secrets: [sessionSecret()],
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'Lax',
  path: '/',
  maxAge: SESSION_SECONDS,
})

const cookieStorage = createCookieSessionStorage()
// Use maintained authenticated encryption for the cookie payload; signing alone
// exposes the Rails bearer credential to anyone who obtains the cookie.
export const sessionStorage: typeof cookieStorage = {
  async read(value) {
    const raw = value
      ? await unsealData<string>(value, { password: sessionSecret(), ttl: SESSION_SECONDS })
      : null
    return cookieStorage.read(typeof raw === 'string' ? raw : null)
  },
  async save(session) {
    const raw = await cookieStorage.save(session)
    return raw ? sealData(raw, { password: sessionSecret(), ttl: SESSION_SECONDS }) : raw
  },
}

export type SignedInSession = {
  token: string
  userId?: string
  permissions?: string[] | null
  roleKey?: string
  email?: string
  name?: string
  organizationId?: string
  organizationSlug?: string
  actingAgentId?: string
  actingAgentName?: string
  demo?: boolean
  lab?: LabContext
}

export type LabContext = {
  surface: 'ui' | 'mcp' | 'api' | 'cli'
  sandbox: 'ui' | 'mcp' | 'api' | 'cli'
  generation: number
  mode: 'explore' | 'compare' | 'connect'
  resetsAt: string
  evidence?: Record<string, string>
  runKey: string
  credentialKey?: string
  toolToken: string
  agentToken: string
}

function currentSession() {
  try {
    return getContext().session
  } catch {
    return null
  }
}

/** The signed-in session for the request being handled, or null. */
export function signedIn(): SignedInSession | null {
  const session = currentSession()
  const token = session?.get('token')
  if (typeof token !== 'string' || !token) return null
  const read = (key: string) => {
    const value = session?.get(key)
    return typeof value === 'string' && value ? value : undefined
  }
  const permissions = session?.get('permissions')
  const storedLab = session?.get('lab') as LabContext | undefined
  const credentials = storedLab?.credentialKey ? readLabCredentials(storedLab.credentialKey) : null
  return {
    token,
    userId: read('userId'),
    permissions: Array.isArray(permissions) ? (permissions as string[]) : null,
    roleKey: read('roleKey'),
    email: read('email'),
    name: read('name'),
    organizationId: read('organizationId'),
    organizationSlug: read('organizationSlug'),
    actingAgentId: read('actingAgentId'),
    actingAgentName: read('actingAgentName'),
    demo: session?.get('demo') === '1',
    lab: storedLab
      ? { ...storedLab, toolToken: credentials?.toolToken ?? '', agentToken: credentials?.agentToken ?? '' }
      : undefined,
  }
}

export function signIn(input: {
  userId?: string
  token: string
  email: string
  name: string
  organizationId: string
  organizationSlug: string
  demo?: boolean
}) {
  const session = currentSession()
  if (!session) throw new Error('session middleware is not installed')
  session.regenerateId()
  session.unset('lab')
  session.set('token', input.token)
  if (input.userId) session.set('userId', input.userId)
  else session.unset('userId')
  session.set('email', input.email)
  session.set('name', input.name)
  session.set('organizationId', input.organizationId)
  session.set('organizationSlug', input.organizationSlug)
  if (input.demo) session.set('demo', '1')
  else session.unset('demo')
  session.unset('actingAgentId')
  session.unset('actingAgentName')
}

/** Effective permissions for the nav, cached at sign-in and on act-as changes. */
export function rememberPermissions(viewer: { permissions: string[]; roleKey?: string | null } | null) {
  const session = currentSession()
  if (!session) return
  if (viewer) {
    session.set('permissions', viewer.permissions)
    if (viewer.roleKey) session.set('roleKey', viewer.roleKey)
  } else {
    session.unset('permissions')
  }
}

export function actAsAgent(agent: { id: string; name: string } | null) {
  const session = currentSession()
  if (!session) return
  if (agent) {
    session.set('actingAgentId', agent.id)
    session.set('actingAgentName', agent.name)
  } else {
    session.unset('actingAgentId')
    session.unset('actingAgentName')
  }
}

const THEME_CHOICES = ['system', 'light', 'dark'] as const
export type ThemeChoice = (typeof THEME_CHOICES)[number]

/** The visitor's theme: system (follow the device), light or dark. */
export function themeChoice(): ThemeChoice {
  const value = currentSession()?.get('theme')
  return THEME_CHOICES.includes(value as ThemeChoice) ? (value as ThemeChoice) : 'system'
}

export function setTheme(value: string) {
  const session = currentSession()
  if (!session) return
  if (THEME_CHOICES.includes(value as ThemeChoice) && value !== 'system') session.set('theme', value)
  else session.unset('theme')
}

export function signOut() {
  currentSession()?.destroy()
}

export function rememberLab(lab: LabContext) {
  const { toolToken, agentToken, ...context } = lab
  const credentialKey =
    context.credentialKey ?? storeLabCredentials({ toolToken, agentToken, expiresAt: lab.resetsAt })
  currentSession()?.set('lab', { ...context, credentialKey })
}

/** One-time notices survive a post/redirect/get without repeating the write. */
export function redirectWithNotice(path: string, notice: string) {
  currentSession()?.set('workflowNotice', notice)
  return new Response(null, { status: 303, headers: { Location: path } })
}

export function takeWorkflowNotice(): string | undefined {
  const session = currentSession()
  const notice = session?.get('workflowNotice')
  session?.unset('workflowNotice')
  return typeof notice === 'string' ? notice : undefined
}
