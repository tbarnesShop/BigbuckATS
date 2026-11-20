/**
 * Pipeline board rules shared by the job workspace. Sections group stages:
 * Sourcing, Applied, Onsite, Offer, Hired. Labels match the usual demo stage
 * names so filter pills and column headers agree. Stage `type` (then key)
 * decides the section. Archived (rejected / withdrawn) is application status,
 * not a stage type. "All" is exactly what the board shows: every candidate in
 * play plus the hired ones, so the five group counts add up to it.
 */
import { routes } from '../routes.ts'

export const BOARD_SECTIONS = [
  { id: 'all', label: 'All' },
  { id: 'lead', label: 'Sourcing' },
  { id: 'review', label: 'Applied' },
  { id: 'active', label: 'Onsite' },
  { id: 'offer', label: 'Offer' },
  { id: 'hired', label: 'Hired' },
  { id: 'closed', label: 'Archived' },
] as const

export type BoardSection = (typeof BOARD_SECTIONS)[number]['id']

export const JOB_TABS = [
  { id: 'pipeline', label: 'Pipeline' },
  { id: 'applications', label: 'Applications' },
  { id: 'sourcing', label: 'Sourcing' },
  { id: 'settings', label: 'Settings' },
] as const

export type JobTab = (typeof JOB_TABS)[number]['id']

export type StageRef = {
  key: string
  name?: string | null
  type?: string | null
}

const TYPE_SECTION: Record<string, Exclude<BoardSection, 'closed' | 'all'>> = {
  lead: 'lead',
  source: 'lead',
  prospect: 'lead',
  sourced: 'lead',
  apply: 'review',
  applied: 'review',
  review: 'review',
  application: 'review',
  screen: 'active',
  interview: 'active',
  assessment: 'active',
  onsite: 'active',
  active: 'active',
  offer: 'offer',
  hired: 'hired',
  hire: 'hired',
}

export function sectionForStage(stage: StageRef): Exclude<BoardSection, 'closed' | 'all'> {
  const type = (stage.type ?? '').toLowerCase()
  if (TYPE_SECTION[type]) return TYPE_SECTION[type]
  const key = stage.key.toLowerCase()
  if (TYPE_SECTION[key]) return TYPE_SECTION[key]
  if (key.includes('hired')) return 'hired'
  if (key.includes('offer')) return 'offer'
  if (key.includes('lead') || key.includes('prospect') || key.includes('sourc')) return 'lead'
  if (key.includes('review') || key.includes('appl')) return 'review'
  return 'active'
}

export function stageLabel(stage: StageRef | undefined, fallback: string): string {
  return stage?.name?.trim() || fallback
}

export type BoardApp = {
  id: string
  status: string
  stageKey: string
  name: string
}

const onBoard = (app: BoardApp) => app.status === 'active' || app.status === 'hired'
const archived = (app: BoardApp) => !onBoard(app)

export function sectionCount(section: BoardSection, stages: StageRef[], apps: BoardApp[]): number {
  if (section === 'all') return apps.filter(onBoard).length
  if (section === 'closed') return apps.filter(archived).length
  if (section === 'hired') return apps.filter((app) => app.status === 'hired').length
  const keys = new Set(stages.filter((stage) => sectionForStage(stage) === section).map((stage) => stage.key))
  return apps.filter((app) => app.status === 'active' && keys.has(app.stageKey)).length
}

/** Show the complete journey first; section pills remain optional filters. */
export function defaultSection(_stages: StageRef[], _apps: BoardApp[]): BoardSection {
  return 'all'
}

export function parseJobTab(value: string | null): JobTab {
  if (value === 'applications' || value === 'sourcing' || value === 'settings' || value === 'pipeline')
    return value
  return 'pipeline'
}

export function parseBoardSection(value: string | null): BoardSection | null {
  if (
    value === 'all' ||
    value === 'lead' ||
    value === 'review' ||
    value === 'active' ||
    value === 'offer' ||
    value === 'hired' ||
    value === 'closed'
  ) {
    return value
  }
  return null
}

export function columnsForSection(section: BoardSection, stages: StageRef[], apps: BoardApp[]): StageRef[] {
  if (section === 'all') return stages
  if (section === 'closed') {
    const keys = new Set(apps.filter(archived).map((app) => app.stageKey))
    return stages.filter((stage) => keys.has(stage.key))
  }
  return stages.filter((stage) => sectionForStage(stage) === section)
}

export function cardsInColumn<T extends BoardApp>(section: BoardSection, stage: StageRef, apps: T[]): T[] {
  return apps.filter((app) => {
    if (section === 'closed') return app.stageKey === stage.key && archived(app)
    // Hired candidates always show in the Hired column, wherever the hire was recorded from, so the
    // column matches the Hired count; every other column holds candidates still in play.
    if (app.status === 'hired') return sectionForStage(stage) === 'hired'
    return app.stageKey === stage.key && app.status === 'active'
  })
}

export function stageEnteredAt(app: {
  currentStageKey?: string | null
  updatedAt?: string | null
  createdAt?: string | null
  transitions?: Array<{
    toStageKey?: string | null
    createdAt?: string | null
  }> | null
}): string | null {
  const hits = (app.transitions ?? []).filter(
    (row) => row.toStageKey === app.currentStageKey && row.createdAt,
  )
  const latest = hits
    .map((row) => row.createdAt as string)
    .sort()
    .at(-1)
  return latest ?? app.updatedAt ?? app.createdAt ?? null
}

/** Compact age for a board card: `5d`, `3h`, `12m`, or `just now`. */
export function stageAgeLabel(iso: string | null | undefined, now = Date.now()): string | null {
  if (!iso) return null
  const then = Date.parse(iso)
  if (!Number.isFinite(then)) return null
  const minutes = Math.floor(Math.max(0, now - then) / 60000)
  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 48) return `${hours}h`
  return `${Math.floor(hours / 24)}d`
}

export type MovePreview =
  | {
      ok: true
      name: string
      fromKey: string
      fromLabel: string
      toKey: string
      toLabel: string
    }
  | { ok: false; message: string }
  | null

export function previewMove(input: {
  applicationId: string
  toStageKey: string
  applications: BoardApp[]
  stages: StageRef[]
}): MovePreview {
  const applicationId = input.applicationId.trim()
  const toStageKey = input.toStageKey.trim()
  if (!applicationId && !toStageKey) return null
  if (!applicationId || !toStageKey) {
    return {
      ok: false,
      message: 'Choose a candidate and a stage to preview the move.',
    }
  }
  const app = input.applications.find((row) => row.id === applicationId)
  if (!app) return { ok: false, message: 'That candidate is not on this job.' }
  if (app.status !== 'active') {
    return {
      ok: false,
      message: 'Only active applications can be moved from the board.',
    }
  }
  const to = input.stages.find((stage) => stage.key === toStageKey)
  if (!to) return { ok: false, message: 'That stage is not on this pipeline.' }
  const toLabel = stageLabel(to, toStageKey)
  if (app.stageKey === toStageKey) {
    return { ok: false, message: `${app.name} is already in ${toLabel}.` }
  }
  const from = input.stages.find((stage) => stage.key === app.stageKey)
  return {
    ok: true,
    name: app.name,
    fromKey: app.stageKey,
    fromLabel: stageLabel(from, app.stageKey),
    toKey: toStageKey,
    toLabel,
  }
}

/** Stages a forward move jumps over that plan interviews. Nothing holds the move; the preview says so. */
export function skippedInterviewStages(
  stages: Array<StageRef & { interviews?: Array<{ required?: boolean }> }>,
  fromKey: string,
  toKey: string,
): string[] {
  const from = stages.findIndex((stage) => stage.key === fromKey)
  const to = stages.findIndex((stage) => stage.key === toKey)
  if (from < 0 || to <= from + 1) return []
  return stages
    .slice(from + 1, to)
    .filter((stage) => (stage.interviews ?? []).some((interview) => interview.required !== false))
    .map((stage) => stageLabel(stage, stage.key))
}

export function jobWorkspaceHref(
  jobId: string,
  orgQuery: string,
  params: Record<string, string | undefined> = {},
): string {
  const search = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : orgQuery)
  for (const [key, value] of Object.entries(params)) {
    if (value) search.set(key, value)
    else search.delete(key)
  }
  const path = routes.jobsShow.index.href({ jobId })
  const query = search.toString()
  return query ? `${path}?${query}` : path
}

export function openingsLabel(count: number): string {
  return count === 1 ? '1 opening' : `${count} openings`
}

export function jobStatusChip(status: string): {
  label: string
  className: string
} {
  const key = status.toLowerCase()
  const label = key === 'active' || key === 'open' ? 'Active' : key.charAt(0).toUpperCase() + key.slice(1)
  if (key === 'active' || key === 'open') return { label, className: 'chip chip-ok' }
  if (key === 'paused' || key === 'draft') return { label, className: 'chip chip-warn' }
  if (key === 'closed' || key === 'archived') return { label, className: 'chip' }
  return { label, className: 'chip chip-info' }
}
