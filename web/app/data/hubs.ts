import { routes } from '../routes.ts'
import { DISPLAY_TIME_ZONE } from './labels.ts'

/**
 * Today, Interviews, and Offers view models. Shapes follow the live Big Buck
 * hubs: an action queue, interview pills with a mine/all scope, and offer
 * status pills with counts. Data comes from GraphQL `today`, `interviews`,
 * and `offers` (the same boards as the REST hub APIs).
 */

export type InterviewScope = 'mine' | 'all'

export const INTERVIEW_TABS = [
  { id: 'upcoming', label: 'Upcoming' },
  { id: 'schedule', label: 'To schedule' },
  { id: 'feedback', label: 'Feedback due' },
  { id: 'mine', label: 'My panels' },
] as const

export type InterviewTabId = (typeof INTERVIEW_TABS)[number]['id']

export const OFFER_TABS = [
  { id: 'drafts', status: 'draft', label: 'Drafts' },
  { id: 'pending', status: 'pending_approval', label: 'Approve' },
  { id: 'changes', status: 'changes_requested', label: 'Changes requested' },
  { id: 'approved', status: 'approved', label: 'Approved' },
  { id: 'sent', status: 'sent', label: 'Sent' },
  { id: 'accepted', status: 'accepted', label: 'Accepted' },
  { id: 'declined', status: 'declined', label: 'Declined' },
  { id: 'expired', status: 'expired', label: 'Expired' },
  { id: 'rescinded', status: 'rescinded', label: 'Rescinded' },
] as const

export type OfferTabId = (typeof OFFER_TABS)[number]['id']

export type QueueKind = 'reviews' | 'feedback' | 'offers'

export type QueueItem = {
  id: string
  kind: QueueKind
  chip: string
  tone: 'ok' | 'warn'
  title: string
  why: string
  cta: string
  href: string
}

export type ActionPill = {
  kind: QueueKind
  label: string
  count: number
  href: string
}

export type CheckItem = {
  id: string
  href: string
  title: string
  meta: string
  detail?: string
}

export type TodayView = {
  dayLabel: string
  interviewsToday: CheckItem[]
  feedbackPending: QueueItem[]
  applicationsHref: string
  needsLine: string
  pills: ActionPill[]
  items: QueueItem[]
  yourInterviews: CheckItem[]
  thisWeek: CheckItem[]
  /** Every upcoming interview of yours this week; `thisWeek` holds the first five. */
  thisWeekTotal: number
  offersPending: number | null
  offersHref: string
  interviewsHref: string
  jobs: Array<{ id: string; title: string; href: string; meta: string }> | null
  analyticsHref: string
  jobsHref: string
}

type PersonName = { displayName: string } | null
type JobTitle = { id?: string; title: string } | null

export type TodayInterview = {
  id: string
  interviewKey: string
  startsAt?: string | null
  interviewerUserIds: string[]
  application?: { id: string; person?: PersonName; job?: JobTitle } | null
}

export type TodayReview = {
  id: string
  person?: PersonName
  job?: { id: string; title: string } | null
}

export type TodayOffer = {
  id: string
  application?: { id: string; person?: PersonName; job?: JobTitle } | null
}

export type TodayJob = {
  id: string
  title: string
  activeCount: number
}

export type HubInterview = {
  id: string
  applicationId: string
  interviewKey: string
  status: string
  startsAt?: string | null
  interviewerUserIds: string[]
  application?: { id: string; person?: PersonName; job?: JobTitle } | null
}

export type HubOffer = {
  id: string
  status: string
  updatedAt: string
  application?: { id: string; person?: PersonName; job?: JobTitle } | null
}

export function withQuery(path: string, params: Record<string, string | undefined>, orgQuery = ''): string {
  const search = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : orgQuery)
  for (const [key, value] of Object.entries(params)) {
    if (value) search.set(key, value)
    else search.delete(key)
  }
  const qs = search.toString()
  return qs ? `${path}?${qs}` : path
}

export function applicationHref(id: string, orgQuery = ''): string {
  return `${routes.applicationsShow.index.href({ applicationId: id })}${orgQuery}`
}

export function interviewHref(id: string, orgQuery = ''): string {
  return `${routes.interviewsShow.href({ interviewId: id })}${orgQuery}`
}

export function offerHref(id: string, orgQuery = ''): string {
  return `${routes.offersShow.index.href({ offerId: id })}${orgQuery}`
}

export function jobHref(id: string, orgQuery = ''): string {
  return `${routes.jobsShow.index.href({ jobId: id })}${orgQuery}`
}

export function interviewsHref(tab: InterviewTabId, scope: InterviewScope, orgQuery = ''): string {
  return withQuery(
    routes.interviewsIndex.href(),
    { tab, scope: scope === 'all' ? 'all' : undefined },
    orgQuery,
  )
}

export function offersTabHref(tab: OfferTabId, orgQuery = ''): string {
  return withQuery(routes.offersIndex.href(), { tab }, orgQuery)
}

export function humanizeKey(key: string): string {
  const words = key.replace(/[_-]+/g, ' ').trim()
  if (!words) return 'Interview'
  return words.replace(/\b\w/g, (char) => char.toUpperCase())
}

export function personLabel(name: string | null | undefined): string {
  // No name means the viewer may not see this person (confidential job or restricted record).
  return name?.trim() ? name : 'Confidential candidate'
}

export function formatWhen(iso: string | null | undefined): string {
  if (!iso) return 'Not scheduled'
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return 'Not scheduled'
  return new Intl.DateTimeFormat('en-US', {
    timeZone: DISPLAY_TIME_ZONE,
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short',
  }).format(date)
}

export function formatAgo(iso: string | null | undefined, now = Date.now()): string {
  if (!iso) return '—'
  const then = new Date(iso).getTime()
  if (Number.isNaN(then)) return '—'
  const days = Math.round((now - then) / 86_400_000)
  if (days <= 0) return 'Today'
  if (days === 1) return '1 day ago'
  return `${days} days ago`
}

export function needsYouLine(count: number): string {
  if (count === 0) return 'Nothing needs you'
  if (count === 1) return '1 thing needs you'
  return `${count} things need you`
}

function interviewCheck(row: TodayInterview, orgQuery: string): CheckItem | null {
  const applicationId = row.application?.id
  if (!applicationId) return null
  const job = row.application?.job?.title
  return {
    id: row.id,
    href: applicationHref(applicationId, orgQuery),
    title: personLabel(row.application?.person?.displayName),
    meta: humanizeKey(row.interviewKey),
    detail: `${formatWhen(row.startsAt)}${job ? ` · ${job}` : ''}`,
  }
}

export function buildTodayView(input: {
  userId: string | null
  reviews: TodayReview[]
  feedback: TodayInterview[]
  upcoming: TodayInterview[]
  offersPending: TodayOffer[] | null
  jobs: TodayJob[] | null
  kind: string | null
  orgQuery?: string
  now?: number
  timeZone?: string
}): TodayView {
  const orgQuery = input.orgQuery ?? ''
  const now = input.now ?? Date.now()
  const timeZone = input.timeZone ?? Intl.DateTimeFormat().resolvedOptions().timeZone
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
  const today = day.format(now)
  const remainingToday = input.upcoming.filter((row) => {
    const start = row.startsAt ? new Date(row.startsAt) : null
    return (
      start &&
      Number.isFinite(start.getTime()) &&
      start.getTime() >= now &&
      day.format(start) === today &&
      !!input.userId &&
      row.interviewerUserIds.includes(input.userId)
    )
  })
  const reviews: QueueItem[] = input.reviews.map((row) => {
    const job = row.job?.title
    return {
      id: `review-${row.id}`,
      kind: 'reviews',
      chip: 'New applicants',
      tone: 'ok',
      title: personLabel(row.person?.displayName),
      why: job ? `${job} · initial review` : 'Awaiting initial review',
      cta: 'Review',
      href: applicationHref(row.id, orgQuery),
    }
  })
  const feedback: QueueItem[] = input.feedback.flatMap((row) => {
    const applicationId = row.application?.id
    if (!applicationId) return []
    const job = row.application?.job?.title
    const kind = humanizeKey(row.interviewKey)
    return [
      {
        id: `feedback-${row.id}`,
        kind: 'feedback' as const,
        chip: 'Feedback due',
        tone: 'warn' as const,
        title: personLabel(row.application?.person?.displayName),
        why: job ? `${kind} · ${job}` : kind,
        cta: 'Scorecard',
        href: applicationHref(applicationId, orgQuery),
      },
    ]
  })
  const offers: QueueItem[] = (input.offersPending ?? []).flatMap((row) => {
    const application = row.application
    const job = application?.job?.title
    return [
      {
        id: `offer-${row.id}`,
        kind: 'offers' as const,
        chip: 'Approve',
        tone: 'warn' as const,
        title: personLabel(application?.person?.displayName),
        why: job ? `Waiting for approval · ${job}.` : 'Waiting for approval.',
        cta: 'Approve',
        href: offerHref(row.id, orgQuery),
      },
    ]
  })

  const pills = (
    [
      {
        kind: 'reviews',
        label: 'New applicants',
        count: reviews.length,
        href: withQuery(routes.today.href(), { kind: 'reviews' }, orgQuery),
      },
      {
        kind: 'feedback',
        label: 'Feedback due',
        count: feedback.length,
        href: withQuery(routes.today.href(), { kind: 'feedback' }, orgQuery),
      },
      {
        kind: 'offers',
        label: 'Approve',
        count: offers.length,
        href: withQuery(routes.today.href(), { kind: 'offers' }, orgQuery),
      },
    ] as const satisfies readonly ActionPill[]
  ).filter((pill) => pill.count > 0 && (pill.kind !== 'offers' || input.offersPending !== null))

  const kind =
    input.kind === 'reviews' || input.kind === 'feedback' || input.kind === 'offers' ? input.kind : null
  const visibleKind = kind && pills.some((pill) => pill.kind === kind) ? kind : null
  const items = [...reviews, ...feedback, ...offers].filter(
    (item) => !visibleKind || item.kind === visibleKind,
  )
  const yours = input.userId
    ? input.upcoming.filter((row) => row.interviewerUserIds.includes(input.userId!))
    : []

  return {
    dayLabel: new Intl.DateTimeFormat('en-US', {
      timeZone,
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      timeZoneName: 'short',
    })
      .format(now)
      .replace(' at ', ' · '),
    interviewsToday: remainingToday.flatMap((row) => {
      const item = interviewCheck(row, orgQuery)
      return item ? [item] : []
    }),
    feedbackPending: feedback,
    applicationsHref: withQuery(routes.today.href(), { kind: 'reviews' }, orgQuery) + '#applications',
    needsLine: needsYouLine(reviews.length + feedback.length + offers.length),
    pills,
    items,
    yourInterviews: yours
      .flatMap((row) => {
        const item = interviewCheck(row, orgQuery)
        return item ? [item] : []
      })
      .slice(0, 5),
    ...(() => {
      const upcoming = yours
        .filter((row) => {
          const start = row.startsAt ? Date.parse(row.startsAt) : NaN
          return Number.isFinite(start) && start >= now && !remainingToday.includes(row)
        })
        .flatMap((row) => {
          const item = interviewCheck(row, orgQuery)
          return item ? [item] : []
        })
      return { thisWeek: upcoming.slice(0, 5), thisWeekTotal: upcoming.length }
    })(),
    offersPending: input.offersPending ? input.offersPending.length : input.offersPending,
    offersHref: offersTabHref('pending', orgQuery),
    interviewsHref: interviewsHref('upcoming', 'mine', orgQuery),
    jobs: input.jobs
      ? input.jobs.map((job) => ({
          id: job.id,
          title: job.title,
          href: jobHref(job.id, orgQuery),
          meta: `${job.activeCount} active ${job.activeCount === 1 ? 'application' : 'applications'}`,
        }))
      : null,
    analyticsHref: `${routes.analytics.href()}${orgQuery}`,
    jobsHref: `${routes.jobsIndex.href()}${orgQuery}`,
  }
}

export function interviewScope(value: string | null): InterviewScope {
  return value === 'all' ? 'all' : 'mine'
}

export function selectInterviewTab(
  requested: string | null,
  counts: Record<InterviewTabId, number>,
): InterviewTabId {
  if (INTERVIEW_TABS.some((tab) => tab.id === requested)) return requested as InterviewTabId
  return INTERVIEW_TABS.find((tab) => counts[tab.id] > 0)?.id ?? 'upcoming'
}

export function interviewStatus(status: string): { label: string; chip: string } {
  if (status === 'scheduled') return { label: 'Scheduled', chip: 'chip kind chip-ok' }
  if (status === 'requested' || status === 'needs_attention')
    return { label: 'To schedule', chip: 'chip kind chip-warn' }
  if (status === 'cancelled') return { label: 'Cancelled', chip: 'chip kind chip-bad' }
  if (status === 'completed') return { label: 'Completed', chip: 'chip kind' }
  return { label: humanizeKey(status), chip: 'chip kind' }
}

export function interviewWhy(row: HubInterview): string {
  const job = row.application?.job?.title
  const kind = humanizeKey(row.interviewKey)
  return job ? `${kind} · ${job}` : kind
}

export function offerCounts(rows: Array<{ status: string; count: number }>): Record<string, number> {
  const counts: Record<string, number> = {}
  for (const tab of OFFER_TABS) counts[tab.status] = 0
  for (const row of rows) counts[row.status] = row.count
  return counts
}

export function selectOfferTab(requested: string | null, counts: Record<string, number>): OfferTabId {
  // Accept the tab id, the stored status, or the visible label (?tab=approve, ?tab=pending_approval).
  const wanted = (requested ?? '').toLowerCase().replace(/[\s-]+/g, '_')
  const match = OFFER_TABS.find(
    (tab) =>
      tab.id === wanted || tab.status === wanted || tab.label.toLowerCase().replace(/\s+/g, '_') === wanted,
  )
  if (match) return match.id
  return OFFER_TABS.find((tab) => (counts[tab.status] ?? 0) > 0)?.id ?? 'drafts'
}

export function offerTabById(id: OfferTabId): (typeof OFFER_TABS)[number] {
  return OFFER_TABS.find((tab) => tab.id === id) ?? OFFER_TABS[0]
}

export function offerStatus(status: string): { label: string; chip: string } {
  if (status === 'pending_approval') return { label: 'Awaiting approval', chip: 'chip chip-warn' }
  if (status === 'changes_requested') return { label: 'Changes requested', chip: 'chip chip-warn' }
  if (status === 'approved' || status === 'accepted')
    return { label: humanizeKey(status), chip: 'chip chip-ok' }
  if (status === 'sent') return { label: 'Sent', chip: 'chip chip-info' }
  if (status === 'declined' || status === 'rescinded')
    return { label: humanizeKey(status), chip: 'chip chip-bad' }
  if (status === 'draft') return { label: 'Draft', chip: 'chip' }
  return { label: humanizeKey(status), chip: 'chip' }
}

export function offerEmptyCopy(tab: OfferTabId): string {
  if (tab === 'drafts') return 'No drafts. An offer starts from a candidate at the offer stage.'
  if (tab === 'pending') return 'Nothing to approve.'
  return 'Nothing in this status.'
}

export function interviewEmptyCopy(tab: InterviewTabId): string {
  if (tab === 'upcoming') return 'Nothing upcoming.'
  if (tab === 'schedule') return 'Nothing to schedule.'
  if (tab === 'feedback') return 'No scorecards due.'
  return 'No panels with you.'
}
