/**
 * Who sees which part of the app. One rule table drives the sidebar and the
 * folded hubs. A rule lists permissions; any one is enough; an empty rule means
 * every signed-in member. Pages still enforce access server-side.
 *
 * Big Buck's live shell folds the product into seven entries. These rules stay
 * the Remix permission vocabulary (read vs manage stay distinct). Create actions
 * use CREATE_RULES so a read permission never reveals a create control.
 */
import { routes } from '../routes.ts'

export type NavRule = readonly string[]

export const NAV_RULES = {
  today: [],
  people: ['person.read'],
  jobs: ['job.read'],
  pools: ['project.read'],
  proposals: ['project.read'],
  sequences: ['sequence.read'],
  analytics: ['analytics.read'],
  referrals: ['referral.read', 'referral.create'],
  requisitions: ['requisition.read'],
  careers: [],
  admin: ['config.plan', 'webhook.manage', 'import.manage', 'audit.read'],
  settings: [],
  branding: ['settings.manage'],
  interviews: ['interview.schedule', 'scorecard.write', 'scorecard.read_all', 'application.read'],
  offers: ['offer.read', 'offer.create', 'offer.approve'],
  fields: ['custom_field.manage'],
  applications: ['application.read'],
  companies: ['person.read'],
  templates: ['sequence.read'],
  mailboxes: ['sequence.read'],
  calendar: ['interview.schedule'],
  imports: ['import.manage'],
  webhooks: ['webhook.manage'],
  applicationForm: ['settings.manage'],
} as const satisfies Record<string, NavRule>

export type NavArea = keyof typeof NAV_RULES

/** Without known permissions (not signed in, or the lookup failed) show everything. */
export function canSee(area: NavArea, permissions: readonly string[] | null | undefined): boolean {
  if (!permissions) return true
  const rule: NavRule = NAV_RULES[area]
  return rule.length === 0 || rule.some((p) => permissions.includes(p))
}

export const CREATE_RULES = {
  job: ['job.manage'],
  person: ['person.create'],
  pool: ['project.manage'],
} as const

export function canCreate(
  needs: readonly string[],
  permissions: readonly string[] | null | undefined,
): boolean {
  if (!permissions) return true
  return needs.some((p) => permissions.includes(p))
}

export type PrimaryId = 'today' | 'jobs' | 'people' | 'interviews' | 'offers' | 'careers' | 'settings'

export type PrimaryIcon = 'sun' | 'briefcase' | 'users' | 'calendar' | 'file' | 'globe' | 'gear'

export type PrimaryItem = {
  id: PrimaryId
  label: string
  href: string
  icon: PrimaryIcon
  areas: readonly NavArea[]
}

/** Longest matching prefix wins, so /settings/careers stays under Settings. */
const PARENT_PREFIXES: ReadonlyArray<{ id: PrimaryId; prefix: string }> = [
  { id: 'settings', prefix: '/settings' },
  { id: 'settings', prefix: '/sequences' },
  { id: 'settings', prefix: '/admin' },
  { id: 'people', prefix: '/people' },
  { id: 'people', prefix: '/pools' },
  { id: 'people', prefix: '/pool-members' },
  { id: 'people', prefix: '/referrals' },
  { id: 'people', prefix: '/companies' },
  { id: 'jobs', prefix: '/jobs' },
  { id: 'jobs', prefix: '/applications' },
  { id: 'jobs', prefix: '/requisitions' },
  { id: 'offers', prefix: '/offers' },
  { id: 'interviews', prefix: '/interviews' },
  { id: 'today', prefix: '/today' },
  { id: 'today', prefix: '/analytics' },
  { id: 'today', prefix: '/proposals' },
  { id: 'careers', prefix: '/careers' },
]

export function activePrimary(pathname: string): PrimaryId | null {
  const path = pathname.split('?')[0] || '/'
  let best: { id: PrimaryId; len: number } | null = null
  for (const row of PARENT_PREFIXES) {
    if (path === row.prefix || path.startsWith(`${row.prefix}/`)) {
      if (!best || row.prefix.length > best.len) best = { id: row.id, len: row.prefix.length }
    }
  }
  return best?.id ?? null
}

/** careersSlug: the signed-in organization, so a lab persona's Careers link opens its own sandbox. */
export function primaryItems(orgQuery: string, careersSlug?: string): PrimaryItem[] {
  const fallback = `?slug=${encodeURIComponent(careersSlug ?? 'big-buck')}`
  const careersHref = `${routes.careersIndex.href()}${orgQuery || fallback}`
  return [
    {
      id: 'today',
      label: 'Today',
      href: routes.today.href(),
      icon: 'sun',
      areas: ['today', 'proposals', 'analytics'],
    },
    {
      id: 'jobs',
      label: 'Jobs',
      href: `${routes.jobsIndex.href()}${orgQuery}`,
      icon: 'briefcase',
      areas: ['jobs', 'requisitions', 'applications'],
    },
    {
      id: 'people',
      label: 'People',
      href: `${routes.peopleIndex.href()}${orgQuery}`,
      icon: 'users',
      areas: ['people', 'pools', 'referrals', 'companies'],
    },
    {
      id: 'interviews',
      label: 'Interviews',
      href: routes.interviewsIndex.href(),
      icon: 'calendar',
      areas: ['interviews'],
    },
    { id: 'offers', label: 'Offers', href: routes.offersIndex.href(), icon: 'file', areas: ['offers'] },
    { id: 'careers', label: 'Careers', href: careersHref, icon: 'globe', areas: ['careers'] },
    {
      id: 'settings',
      label: 'Settings',
      href: routes.settingsIndex.href(),
      icon: 'gear',
      areas: ['settings'],
    },
  ]
}

export type FoldLink = {
  label: string
  href: string
  area: NavArea
  hint: string
}

export function foldLinks(parent: PrimaryId, orgQuery = ''): FoldLink[] {
  const q = orgQuery
  if (parent === 'today') {
    return [
      {
        label: 'My day',
        href: `${routes.today.href()}${q}`,
        area: 'today',
        hint: 'Your schedule and queues',
      },
      {
        label: 'Approvals',
        href: `${routes.proposals.index.href()}${q}`,
        area: 'proposals',
        hint: 'Agent suggestions to approve',
      },
      {
        label: 'Analytics',
        href: `${routes.analytics.href()}${q}`,
        area: 'analytics',
        hint: 'Hiring and outreach results',
      },
    ]
  }
  if (parent === 'people') {
    return [
      {
        label: 'Directory',
        href: `${routes.peopleIndex.href()}${q}`,
        area: 'people',
        hint: 'Candidates and prospects',
      },
      { label: 'Pools', href: `${routes.poolsIndex.href()}${q}`, area: 'pools', hint: 'Sourcing lists' },
      {
        label: 'Referrals',
        href: `${routes.referrals.index.href()}${q}`,
        area: 'referrals',
        hint: 'Employee intros',
      },
      {
        label: 'Companies',
        href: `${routes.companiesIndex.href()}${q}`,
        area: 'companies',
        hint: 'Where people work',
      },
    ]
  }
  if (parent === 'jobs') {
    return [
      { label: 'Jobs', href: `${routes.jobsIndex.href()}${q}`, area: 'jobs', hint: 'Pipelines' },
      {
        label: 'Applications',
        href: `${routes.applicationsIndex.href()}${q}`,
        area: 'applications',
        hint: 'Across jobs',
      },
      {
        label: 'Archived',
        href: `${routes.applicationsIndex.href()}${q ? `${q}&` : '?'}status=archived`,
        area: 'applications',
        hint: 'Rejected and withdrawn',
      },
      {
        label: 'Internal careers',
        href: routes.internalCareers.href(),
        area: 'careers',
        hint: 'Employee opportunities',
      },
      {
        label: 'Openings',
        href: `${routes.requisitions.index.href()}${q}`,
        area: 'requisitions',
        hint: 'Headcount',
      },
    ]
  }
  if (parent === 'settings') {
    return [
      { label: 'Overview', href: routes.settingsIndex.href(), area: 'settings', hint: 'All settings' },
      { label: 'Team', href: routes.settingsTeam.href(), area: 'jobs', hint: 'Members and roles' },
      {
        label: 'Templates',
        href: routes.settingsTemplates.index.href(),
        area: 'templates',
        hint: 'Message templates',
      },
      {
        label: 'Question templates',
        href: routes.questionTemplates.index.href(),
        area: 'jobs',
        hint: 'Reusable posting questions',
      },
      {
        label: 'Scorecards',
        href: routes.settingsScorecards.index.href(),
        area: 'applications',
        hint: 'What interviewers rate',
      },
      {
        label: 'Application form',
        href: routes.settingsForm.index.href(),
        area: 'applicationForm',
        hint: 'Required fields and screening',
      },
      {
        label: 'Mailboxes',
        href: routes.settingsMailboxes.index.href(),
        area: 'mailboxes',
        hint: 'Connected inboxes',
      },
      {
        label: 'Calendar',
        href: routes.settingsCalendar.index.href(),
        area: 'calendar',
        hint: 'Interviewer calendars',
      },
      { label: 'Import', href: routes.settingsImport.index.href(), area: 'imports', hint: 'People CSV' },
      {
        label: 'Careers page',
        href: `${routes.careersSettings.index.href()}${q}`,
        area: 'branding',
        hint: 'Public brand',
      },
      {
        label: 'Webhooks',
        href: routes.settingsWebhooks.index.href(),
        area: 'webhooks',
        hint: 'Outbound events',
      },
      {
        label: 'Agents',
        href: routes.settingsAgents.index.href(),
        area: 'settings',
        hint: 'Act-as access and MCP',
      },
      {
        label: 'API keys',
        href: routes.settingsKeys.index.href(),
        area: 'settings',
        hint: 'Personal tokens',
      },
      {
        label: 'Custom fields',
        href: routes.settingsFields.index.href(),
        area: 'fields',
        hint: 'Versioned fields',
      },
      {
        label: 'Sequences',
        href: `${routes.sequencesIndex.href()}${q}`,
        area: 'sequences',
        hint: 'Outreach',
      },
      {
        label: 'Tasks',
        href: `${routes.tasks.index.href()}${q}`,
        area: 'sequences',
        hint: 'Follow-ups',
      },
      { label: 'Admin', href: `${routes.admin.index.href()}${q}`, area: 'admin', hint: 'Config and events' },
    ]
  }
  return []
}

/** Index links stay current only on the index, so child pages don't light the parent row. */
const EXACT_FOLD = new Set(['/people', '/jobs', '/settings'])

/** `location` may include a query; a link that names a `status` view matches only that view. */
export function isFoldCurrent(href: string, location: string): boolean {
  const [pathname = '/', search = ''] = location.split('?')
  const target = href.split('#')[0]?.split('?')[0] || '/'
  const wanted = new URLSearchParams(href.split('#')[0]?.split('?')[1] ?? '').get('status')
  const status = new URLSearchParams(search).get('status')
  // Archived has its own link; other status views (Hired, All) stay under the plain list link.
  if (pathname === target) return wanted === status || (wanted === null && status !== 'archived')
  if (wanted !== null) return false
  if (EXACT_FOLD.has(target)) return false
  return pathname.startsWith(`${target}/`)
}

export type CreateItem = {
  href: string
  label: string
  hint: string
  needs: readonly string[]
}

export function createItems(orgQuery = ''): CreateItem[] {
  const q = orgQuery
  return [
    {
      href: `${routes.jobsCreate.index.href()}${q}`,
      label: 'New job',
      hint: 'Open a requisition board',
      needs: CREATE_RULES.job,
    },
    {
      href: `${routes.peopleCreate.index.href()}${q}`,
      label: 'New person',
      hint: 'Add a candidate or prospect',
      needs: CREATE_RULES.person,
    },
    {
      href: `${routes.poolsCreate.index.href()}${q}`,
      label: 'New talent pool',
      hint: 'Start a sourcing list',
      needs: CREATE_RULES.pool,
    },
  ]
}

export function roleLabel(roleKey?: string): string | undefined {
  if (!roleKey) return undefined
  return roleKey
    .split('_')
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
}

export type SettingsCard = { href: string; title: string; blurb: string; area: NavArea }

export function settingsCards(orgQuery = ''): SettingsCard[] {
  const q = orgQuery
  return [
    {
      area: 'jobs',
      href: routes.settingsTeam.href(),
      title: 'Team',
      blurb: 'Who is in the workspace, their roles, and what each role can do.',
    },
    {
      area: 'templates',
      href: routes.settingsTemplates.index.href(),
      title: 'Templates',
      blurb: 'Message templates for outreach and offers.',
    },
    {
      area: 'jobs',
      href: routes.questionTemplates.index.href(),
      title: 'Question templates',
      blurb: 'Reusable application questions owned by recruiters.',
    },
    {
      area: 'applications',
      href: routes.settingsScorecards.index.href(),
      title: 'Scorecards',
      blurb: 'What interviewers rate in each kind of interview.',
    },
    {
      area: 'applicationForm',
      href: routes.settingsForm.index.href(),
      title: 'Application form',
      blurb: 'Organization questions included on external and internal application forms.',
    },
    {
      area: 'mailboxes',
      href: routes.settingsMailboxes.index.href(),
      title: 'Mailboxes',
      blurb: 'Connected inboxes.',
    },
    {
      area: 'calendar',
      href: routes.settingsCalendar.index.href(),
      title: 'Calendar',
      blurb: 'Calendars interviewers use to book panels.',
    },
    {
      area: 'imports',
      href: routes.settingsImport.index.href(),
      title: 'Import',
      blurb: 'Bring people in from a CSV. Dry-run first.',
    },
    {
      area: 'branding',
      href: `${routes.careersSettings.index.href()}${q}`,
      title: 'Careers page',
      blurb: 'Hero, headline and public careers copy.',
    },
    {
      area: 'webhooks',
      href: routes.settingsWebhooks.index.href(),
      title: 'Webhooks',
      blurb: 'HTTPS endpoints for events. Private addresses are refused.',
    },
    {
      area: 'settings',
      href: routes.settingsAgents.index.href(),
      title: 'Agents',
      blurb: 'Give agents a slice of your access, and connect MCP with their token.',
    },
    {
      area: 'settings',
      href: routes.settingsKeys.index.href(),
      title: 'API keys',
      blurb: 'Personal tokens for scripts, the CLI and the SDK.',
    },
    {
      area: 'fields',
      href: routes.settingsFields.index.href(),
      title: 'Custom fields',
      blurb: 'Add fields to people, jobs and applications. Fields are versioned and archived, never deleted.',
    },
    {
      area: 'sequences',
      href: `${routes.sequencesIndex.href()}${q}`,
      title: 'Sequences',
      blurb: '',
    },
    {
      area: 'admin',
      href: `${routes.admin.index.href()}${q}`,
      title: 'Admin',
      blurb: 'Config as code and recent events.',
    },
  ]
}
