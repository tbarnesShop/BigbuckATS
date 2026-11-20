import { createController } from 'remix/router'
import type { AppContext } from '../../router.ts'

import {
  addPeopleToPool,
  bulkPeopleAction,
  createPerson,
  createSavedSearch,
  deleteSavedSearch,
  listPeople,
  listProjects,
  listSavedSearches,
  listSequences,
  sessionFromEnv,
  sessionFromRequest,
  type ApiHeaders,
} from '../../data/api.ts'
import { redirectWithNotice } from '../../data/auth.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { PeopleIndexPage, PersonCreatePage, type BulkSelection } from './pages.tsx'

const ADVANCED_KEYS = ['tag', 'source', 'engagement_status', 'location', 'not_contacted_days'] as const
type AdvancedKey = (typeof ADVANCED_KEYS)[number]

type PeopleFilters = {
  q: string
  lifecycle_stage: string
  project_id: string
} & Partial<Record<AdvancedKey, string>>

function peopleIndexHref(org: string, filters: PeopleFilters) {
  const params = new URLSearchParams(org.replace(/^\?/, ''))
  for (const [key, value] of Object.entries(filters)) {
    if (value) params.set(key, value)
    else params.delete(key)
  }
  const text = params.toString()
  return `${routes.peopleIndex.href()}${text ? `?${text}` : ''}`
}

async function peoplePage(
  session: ApiHeaders,
  org: string,
  filters: PeopleFilters,
  notice?: string,
  bulk?: BulkSelection,
) {
  const [people, sequences, projects, saved] = await Promise.all([
    listPeople(session, {
      q: filters.q || undefined,
      lifecycle_stage: filters.lifecycle_stage || undefined,
      project_id: filters.project_id || undefined,
      ...Object.fromEntries(ADVANCED_KEYS.map((k) => [k, filters[k] || undefined])),
      limit: 50,
    }),
    listSequences(session).catch(() => ({ data: [] })),
    listProjects(session).catch(() => ({ data: [] })),
    listSavedSearches(session).catch(() => ({ data: [] })),
  ])
  return (
    <PeopleIndexPage
      people={people.data}
      sequences={sequences.data}
      projects={projects.data}
      savedSearches={saved.data}
      filters={filters}
      orgQuery={org}
      notice={notice}
      bulk={bulk}
      page={people.meta?.page ?? 1}
      total={people.meta?.total}
      perPage={people.meta?.per_page ?? 50}
    />
  )
}

/** Posts from the people list (POST /people) and the new-person form (POST /people/new). */
export async function peopleFormAction(context: AppContext) {
  const session = sessionFromRequest(context.url) ?? sessionFromEnv()
  if (!session) return context.render(<SetupNeeded />)
  const form = await context.request.formData()
  const intent = String(form.get('intent') ?? 'create')
  const q = String(form.get('q') ?? '')
  const lifecycle = String(form.get('lifecycle_stage') ?? '')
  const projectId = String(form.get('project_id') ?? '')
  const advanced = Object.fromEntries(ADVANCED_KEYS.map((k) => [k, String(form.get(k) ?? '')])) as Record<
    AdvancedKey,
    string
  >
  const filters = { q, lifecycle_stage: lifecycle, project_id: projectId, ...advanced }
  const org = orgQuery(context.url)

  try {
    if (intent === 'search') {
      return context.render(await peoplePage(session, org, filters))
    }

    if (intent === 'save_search') {
      const name = String(form.get('name') ?? '').trim()
      if (!name) throw new Error('Name the search')
      const savedFilters: Record<string, string> = {}
      if (q) savedFilters.q = q
      if (lifecycle) savedFilters.lifecycle_stage = lifecycle
      if (projectId) savedFilters.project_id = projectId
      for (const k of ADVANCED_KEYS) if (advanced[k]) savedFilters[k] = advanced[k]
      await createSavedSearch(session, { name, filters: savedFilters })
      return redirectWithNotice(peopleIndexHref(org, filters), `Saved “${name}”`)
    }

    if (intent === 'delete_search') {
      await deleteSavedSearch(session, String(form.get('id') ?? ''))
      return redirectWithNotice(peopleIndexHref(org, filters), 'Removed saved search')
    }

    if (intent === 'bulk_dnc' || intent === 'bulk_enroll' || intent === 'bulk_pool') {
      const personIds = form.getAll('person_id').map(String).filter(Boolean)
      if (personIds.length === 0) throw new Error('Select at least one person.')
      if (intent === 'bulk_dnc') {
        await bulkPeopleAction(session, {
          bulk_action: 'set_dnc',
          person_ids: personIds,
          reason: 'manual',
        })
        return redirectWithNotice(peopleIndexHref(org, filters), `Updated ${personIds.length} people`)
      } else if (intent === 'bulk_pool') {
        const projectId = String(form.get('bulk_project_id') ?? '')
        if (!projectId) throw new Error('Choose a pool to add the selected people to.')
        const result = await addPeopleToPool(session, projectId, { person_ids: personIds })
        return redirectWithNotice(
          peopleIndexHref(org, filters),
          `Added ${result.added} to the pool${result.already_members ? `, ${result.already_members} already in it` : ''}.`,
        )
      } else {
        const sequenceId = String(form.get('sequence_id') ?? '')
        if (!sequenceId) throw new Error('Choose a sequence to enroll the selected people in.')
        // Nothing is sent from here: the sequence page shows who would be enrolled and who is skipped, and why.
        const review = new URLSearchParams(org.replace(/^\?/, ''))
        review.set('review', personIds.join(','))
        return new Response(null, {
          status: 303,
          headers: {
            Location: `${routes.sequencesShow.index.href({ sequenceId })}?${review}#enroll-review`,
          },
        })
      }
    }

    const displayName = String(form.get('display_name') ?? '').trim()
    const email = String(form.get('email') ?? '').trim()
    if (!displayName) throw new Error('Name is required')
    const person = await createPerson(session, {
      display_name: displayName,
      email: email || undefined,
    })
    // Open the new record (a long A–Z list may not show it on page 1); from there it can join a job.
    return redirectWithNotice(
      `${routes.peopleShow.index.href({ personId: person.id })}${org}`,
      person.attached
        ? `${displayName} already existed; opened their record.`
        : `Created ${displayName}. Add them to a job below.`,
    )
  } catch (error) {
    const message = `Could not complete: ${error instanceof Error ? error.message : String(error)}`
    if (intent === 'create') {
      return context.render(<PersonCreatePage orgQuery={org} notice={message} />)
    }
    // Keep what was checked and chosen, so fixing the one missing choice is a single click.
    const bulk: BulkSelection = {
      personIds: form.getAll('person_id').map(String).filter(Boolean),
      projectId: String(form.get('bulk_project_id') ?? '') || undefined,
      sequenceId: String(form.get('sequence_id') ?? '') || undefined,
    }
    return context.render(await peoplePage(session, org, filters, message, bulk))
  }
}

export default createController(routes.peopleCreate, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      return context.render(<PersonCreatePage orgQuery={orgQuery(context.url)} />)
    },
    action: peopleFormAction,
  },
})
