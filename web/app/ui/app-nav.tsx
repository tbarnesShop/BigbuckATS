import type { Handle } from 'remix/component'
import { getContext } from 'remix/middleware/async-context'

import { signedIn } from '../data/auth.ts'
import {
  activePrimary,
  canCreate,
  canSee,
  createItems,
  foldLinks,
  isFoldCurrent,
  primaryItems,
  roleLabel,
  type PrimaryIcon,
  type PrimaryId,
} from '../data/nav.ts'
import { routes } from '../routes.ts'
import { Brand } from './brand.tsx'
import { SectionTabs, type ChromeLink } from './page-chrome.tsx'
import { CreateActions, MobileNavigation } from './public/navigation.tsx'

function pathAndSearch(): string {
  try {
    const url = getContext().url
    return `${url.pathname}${url.search}`
  } catch {
    return '/'
  }
}

export function AppNav(handle: Handle<{ orgQuery?: string }>) {
  return () => {
    let orgQuery = handle.props.orgQuery ?? ''
    return (
      <aside class="app-nav">
        <div class="app-nav-brand">
          <Brand href={signedIn() ? routes.today.href() : routes.home.href()} />
          <div class="app-nav-brand-actions">
            <ThemeToggle variant="bar" />
            <MobileDrawer orgQuery={orgQuery} />
          </div>
        </div>
        <div class="app-nav-desktop">
          <PrimaryNav orgQuery={orgQuery} />
          <NavFoot />
        </div>
      </aside>
    )
  }
}

export function CreateMenu(handle: Handle<{ orgQuery?: string }>) {
  return () => {
    let current = signedIn()
    if (!current) return null
    let items = createItems(handle.props.orgQuery ?? '').filter((item) =>
      canCreate(item.needs, current.permissions ?? null),
    )
    if (items.length === 0) return null
    return <CreateActions items={items} />
  }
}

function visiblePrimary(orgQuery: string) {
  let current = signedIn()
  let permissions = current ? (current.permissions ?? null) : ([] as string[])
  return primaryItems(orgQuery, current?.organizationSlug).filter((item) => {
    if (!current) return item.id === 'careers'
    return item.areas.some((area) => canSee(area, permissions))
  })
}

function PrimaryNav(handle: Handle<{ orgQuery: string }>) {
  return () => {
    let orgQuery = handle.props.orgQuery
    let current = signedIn()
    let permissions = current ? (current.permissions ?? null) : ([] as string[])
    let path = pathAndSearch()
    let parent = activePrimary(path.split('?')[0] ?? '/')
    let items = visiblePrimary(orgQuery)
    let subs =
      current && parent ? foldLinks(parent, orgQuery).filter((link) => canSee(link.area, permissions)) : []
    let showSubs = subs.length > 1
    return (
      <nav aria-label="Primary" class="app-nav-list">
        {items.map((item) => (
          <div key={item.id} class="nav-group">
            <a class="nav-link" href={item.href} aria-current={parent === item.id ? 'page' : undefined}>
              <span class="nav-link-inner">
                <NavIcon name={item.icon} />
                <span>{item.label}</span>
              </span>
            </a>
            {showSubs && parent === item.id ? (
              <div class="nav-sub" role="group" aria-label={`${item.label} sections`}>
                {subs.map((link) => (
                  <a
                    key={link.label}
                    class="nav-sub-link"
                    href={link.href}
                    aria-current={isFoldCurrent(link.href, path) ? 'page' : undefined}
                  >
                    {link.label}
                  </a>
                ))}
              </div>
            ) : null}
          </div>
        ))}
      </nav>
    )
  }
}

function NavFoot() {
  return () => {
    let current = signedIn()
    return (
      <div class="nav-foot">
        <ThemeToggle />
        {current ? (
          <div class="lens">
            <span class="eyebrow">Signed in as</span>
            <strong>{current.name || current.email || 'Member'}</strong>
            <span>
              {[
                roleLabel(current.roleKey),
                current.organizationSlug,
                current.actingAgentName ? `acting as ${current.actingAgentName}` : null,
              ]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </div>
        ) : (
          <a class="nav-link" href={routes.session.index.href()}>
            Sign in
          </a>
        )}
        {current ? <SignOutButton /> : null}
      </div>
    )
  }
}

function SignOutButton() {
  return () => (
    <form method="post" action={routes.session.action.href()}>
      <input type="hidden" name="intent" value="sign-out" />
      <button class="btn btn-ghost nav-signout" type="submit">
        Sign out
      </button>
    </form>
  )
}

function MobileDrawer(handle: Handle<{ orgQuery: string }>) {
  return () => {
    let orgQuery = handle.props.orgQuery
    let current = signedIn()
    let permissions = current ? (current.permissions ?? null) : ([] as string[])
    let shortcuts = [
      canSee('applications', permissions)
        ? { label: 'Applications', href: `${routes.applicationsIndex.href()}${orgQuery}` }
        : null,
      { label: 'Search', href: `${routes.search.href()}${orgQuery}` },
      canSee('sequences', permissions)
        ? { label: 'Sequences', href: `${routes.sequencesIndex.href()}${orgQuery}` }
        : null,
    ].filter(Boolean) as Array<{ label: string; href: string }>
    return (
      <MobileNavigation>
        <PrimaryNav orgQuery={orgQuery} />
        {shortcuts.length ? (
          <nav class="nav-drawer-shortcuts" aria-label="Shortcuts">
            {shortcuts.map((link) => (
              <a key={link.label} class="nav-link" href={link.href}>
                <span class="nav-link-inner">
                  <span>{link.label}</span>
                </span>
              </a>
            ))}
          </nav>
        ) : null}
        <div class="nav-foot nav-drawer-foot">
          {current ? (
            <div class="lens">
              <span class="eyebrow">Signed in as</span>
              <strong>{current.name || current.email || 'Member'}</strong>
              <span>
                {[roleLabel(current.roleKey), current.organizationSlug].filter(Boolean).join(' · ')}
              </span>
            </div>
          ) : (
            <a class="nav-link" href={routes.session.index.href()}>
              Sign in
            </a>
          )}
          {current ? <SignOutButton /> : null}
        </div>
      </MobileNavigation>
    )
  }
}

/**
 * One sun button that flips light/dark. Two submit buttons share the slot and CSS shows the one
 * that leads away from the theme on screen, so it also works while following the system theme.
 */
export function ThemeToggle(handle: Handle<{ variant?: 'bar' }>) {
  return () => (
    <form
      method="post"
      action={routes.theme.action.href()}
      aria-label="Theme"
      class={handle.props.variant === 'bar' ? 'theme-switch theme-switch-bar' : 'theme-switch'}
    >
      <input type="hidden" name="return_to" value={pathAndSearch()} />
      <button
        type="submit"
        name="theme"
        value="dark"
        class="theme-to-dark"
        aria-label="Switch to dark theme"
        title="Switch to dark theme"
      >
        <NavIcon name="sun" />
      </button>
      <button
        type="submit"
        name="theme"
        value="light"
        class="theme-to-light"
        aria-label="Switch to light theme"
        title="Switch to light theme"
      >
        <NavIcon name="sun" />
      </button>
    </form>
  )
}

function NavIcon(handle: Handle<{ name: PrimaryIcon }>) {
  return () => {
    let name = handle.props.name
    if (name === 'sun') {
      return (
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
      )
    }
    if (name === 'briefcase') {
      return (
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <rect x="3" y="7" width="18" height="13" rx="2" />
          <path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
        </svg>
      )
    }
    if (name === 'users') {
      return (
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <circle cx="9" cy="8" r="3.5" />
          <path d="M2.5 19a6.5 6.5 0 0 1 13 0" />
          <circle cx="17" cy="9" r="2.5" />
          <path d="M16 19a5 5 0 0 1 5.5-4.8" />
        </svg>
      )
    }
    if (name === 'calendar') {
      return (
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <rect x="3" y="5" width="18" height="16" rx="2" />
          <path d="M3 10h18M8 3v4M16 3v4" />
        </svg>
      )
    }
    if (name === 'file') {
      return (
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" />
          <path d="M14 3v5h5" />
        </svg>
      )
    }
    if (name === 'globe') {
      return (
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="9" />
          <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
        </svg>
      )
    }
    return (
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
        aria-hidden="true"
      >
        {/* A gear (Settings), distinct from Today's sun. */}
        <circle cx="12" cy="12" r="3" />
        <path
          stroke-linejoin="round"
          d="M10.3 3h3.4l.5 2.4 1.6.9 2.3-.8 1.7 2.9-1.8 1.6v1.9l1.8 1.6-1.7 2.9-2.3-.8-1.6.9-.5 2.4h-3.4l-.5-2.4-1.6-.9-2.3.8-1.7-2.9 1.8-1.6v-1.9L4.2 8.4l1.7-2.9 2.3.8 1.6-.9z"
        />
      </svg>
    )
  }
}

/** Fold destinations under a primary nav item, as section tabs. */
export function FoldSectionTabs(handle: Handle<{ label: string; parent: PrimaryId; orgQuery?: string }>) {
  return () => {
    let links = foldSectionLinks(handle.props.parent, handle.props.orgQuery ?? '')
    return <SectionTabs label={handle.props.label} links={links} />
  }
}

export function foldSectionLinks(parent: PrimaryId, orgQuery: string): ChromeLink[] {
  let current = signedIn()
  if (!current) return []
  let path = pathAndSearch()
  return foldLinks(parent, orgQuery)
    .filter((link) => canSee(link.area, current.permissions ?? null))
    .map((link) => ({ href: link.href, label: link.label, current: isFoldCurrent(link.href, path) }))
}
