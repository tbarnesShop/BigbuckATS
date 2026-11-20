import type { Handle } from 'remix/component'

import type { DemoMembership } from '../data/api.ts'
import { signedIn } from '../data/auth.ts'
import { canSee, primaryItems } from '../data/nav.ts'
import { routes } from '../routes.ts'
import { Brand } from '../ui/brand.tsx'
import { Shell } from '../ui/shell.tsx'

const CHANNELS = [
  { name: 'CLI', detail: 'Company setup and recruiter verbs from the terminal.' },
  { name: 'API', detail: 'REST for public pages, OAuth, webhooks, and the SDK.' },
  { name: 'MCP', detail: 'Agents call the same API. Tokens live under Settings → Agents.' },
  { name: 'UI', detail: 'Today, jobs, people, interviews, and offers in this app.' },
] as const

/** Public landing. Signed-in home stays the in-app command list. */
export function LandingPage(handle: Handle<{ roles: DemoMembership[]; slug: string }>) {
  return () => {
    let { roles, slug } = handle.props
    return (
      <Shell title="Big Buck" bare>
        <div class="landing">
          <div class="landing-wrap">
            <Brand href={routes.session.index.href()} class="landing-brand" />
            <p class="landing-kicker">CLI · API · MCP · UI</p>
            <h1>The Agent First ATS for teams that move fast</h1>
            <p class="landing-lead">
              One hiring system for people, jobs, and agents. Demo sign-in uses memberships that already
              exist.
            </p>
            <div class="channel-grid">
              {CHANNELS.map((channel) => (
                <section key={channel.name} class="section-card">
                  <h2>{channel.name}</h2>
                  <p class="sub">{channel.detail}</p>
                </section>
              ))}
            </div>
            <h2>Open a role</h2>
            {roles.length === 0 ? (
              <p class="sub">
                No demo memberships are published for this workspace.{' '}
                <a href={routes.session.index.href()}>Sign in</a> if you already have one.
              </p>
            ) : (
              <ul class="role-grid" aria-label="Demo roles">
                {roles.map((role) => (
                  <li key={role.email}>
                    <form method="post" action={routes.session.action.href()}>
                      <input type="hidden" name="email" value={role.email} />
                      <input type="hidden" name="slug" value={slug} />
                      <button class="btn btn-ghost" type="submit">
                        <span>{role.role_name || role.name}</span>
                        <span class="hint">{role.email}</span>
                      </button>
                    </form>
                  </li>
                ))}
              </ul>
            )}
            <p class="sub">
              <a href={routes.session.index.href()}>Email sign-in</a>
              {' · '}
              <a href={`${routes.careersIndex.href()}?slug=${encodeURIComponent(slug)}`}>Careers</a>
            </p>
          </div>
        </div>
      </Shell>
    )
  }
}

/** Signed-in home sits in the sidebar shell. */
export function HomePage(handle: Handle<{ orgQuery?: string }>) {
  return () => {
    let orgQuery = handle.props.orgQuery ?? ''
    let current = signedIn()
    let permissions = current ? (current.permissions ?? null) : null
    let details: Record<string, string> = {
      today: 'What needs you, and why',
      jobs: 'Pipelines and openings',
      people: 'Directory, pools and referrals',
      interviews: 'Schedule and scorecards',
      offers: 'Offers across jobs',
      careers: 'Public brand page',
      settings: 'Agents, templates, branding, admin',
    }
    let links = primaryItems(orgQuery, current?.organizationSlug)
      .filter((item) => !current || item.areas.some((area) => canSee(area, permissions)))
      .map((item) => ({ href: item.href, label: item.label, detail: details[item.id] ?? '' }))
    return (
      <Shell title="Big Buck" eyebrow="Hiring ops" orgQuery={orgQuery}>
        <p class="sub mute">People, jobs, sourcing and a public careers page — over the same API.</p>
        <nav aria-label="Command actions">
          <ul class="queue">
            {links.map((item) => (
              <li key={item.label} class="queue-item">
                <a class="command-link" href={item.href}>
                  <span class="body">
                    <span class="title">{item.label}</span>
                    <span class="why">{item.detail}</span>
                  </span>
                </a>
              </li>
            ))}
            {current ? null : (
              <li class="queue-item">
                <a class="command-link" href={routes.session.index.href()}>
                  <span class="body">
                    <span class="title">Sign in</span>
                    <span class="why">Demo session and roles</span>
                  </span>
                </a>
              </li>
            )}
          </ul>
        </nav>
      </Shell>
    )
  }
}
