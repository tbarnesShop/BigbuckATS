/**
 * One command list for the ⌘K bar and the plain search page.
 * Visibility uses the same rules as the sidebar.
 */
import { signedIn } from './auth.ts'
import {
  canCreate,
  canSee,
  createItems,
  foldLinks,
  primaryItems,
  settingsCards,
  type NavArea,
} from './nav.ts'
import { routes } from '../routes.ts'

export type Command = {
  id: string
  label: string
  hint: string
  href: string
  group: 'Go' | 'Create' | 'Settings'
  areas: readonly NavArea[]
  needs?: readonly string[]
  public?: boolean
}

export function commandList(orgQuery = ''): Command[] {
  const go: Command[] = primaryItems(orgQuery, signedIn()?.organizationSlug).map((item) => ({
    id: `go-${item.id}`,
    label: item.label,
    hint: item.id === 'today' ? 'What needs you' : 'Open',
    href: item.href,
    group: 'Go',
    areas: item.areas,
    public: item.id === 'careers',
  }))
  const folds: Command[] = (['people', 'jobs', 'settings'] as const).flatMap((parent) =>
    foldLinks(parent, orgQuery).map((link) => ({
      id: `fold-${parent}-${link.label}`,
      label: link.label,
      hint: link.hint,
      href: link.href,
      group: parent === 'settings' ? ('Settings' as const) : ('Go' as const),
      areas: [link.area],
    })),
  )
  const create: Command[] = createItems(orgQuery).map((item) => ({
    id: `create-${item.label}`,
    label: item.label,
    hint: item.hint,
    href: item.href,
    group: 'Create',
    areas: [],
    needs: item.needs,
  }))
  const settings: Command[] = settingsCards(orgQuery).map((card) => ({
    id: `settings-${card.title}`,
    label: card.title,
    hint: card.blurb,
    href: card.href,
    group: 'Settings',
    areas: [card.area],
  }))
  const signIn: Command = {
    id: 'sign-in',
    label: 'Sign in',
    hint: 'Demo roles and email',
    href: routes.session.index.href(),
    group: 'Go',
    areas: [],
    public: true,
  }
  const seen = new Set<string>()
  return [...go, ...folds, ...create, ...settings, signIn].filter((command) => {
    const key = `${command.href} ${command.label}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

export function visibleCommands(commands: readonly Command[]): Command[] {
  const current = signedIn()
  if (!current) return commands.filter((command) => command.public)
  const permissions = current.permissions ?? null
  return commands.filter((command) => {
    if (command.public && command.id === 'sign-in') return false
    if (command.needs) return canCreate(command.needs, permissions)
    if (command.areas.length === 0) return true
    return command.areas.some((area) => canSee(area, permissions))
  })
}

export function filterCommands(commands: readonly Command[], query: string): Command[] {
  const needle = query.trim().toLowerCase()
  if (!needle) return [...commands]
  return commands.filter((command) =>
    `${command.label} ${command.hint} ${command.group}`.toLowerCase().includes(needle),
  )
}
