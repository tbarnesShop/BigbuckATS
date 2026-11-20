import type { Handle, RemixNode } from 'remix/component'

import { Document } from '../actions/document.tsx'
import { LiveBanner } from '../actions/lab/public/live-banner.tsx'
import { signedIn } from '../data/auth.ts'
import { commandList, visibleCommands } from '../data/commands.ts'
import { routes } from '../routes.ts'
import { AppNav, CreateMenu } from './app-nav.tsx'
import { SettingsNavigation } from './settings-nav.tsx'
import { CommandBar } from './public/command-bar.tsx'

export function Shell(
  handle: Handle<{
    title: string
    children?: RemixNode
    eyebrow?: string
    sub?: string
    bare?: boolean
    wide?: boolean
    orgQuery?: string
    backHref?: string
    backLabel?: string
    titleActions?: RemixNode
  }>,
) {
  return () => {
    let { title, children, eyebrow, sub, bare, wide, orgQuery = '', backHref, backLabel } = handle.props
    const current = signedIn()
    const demoBanner = current?.demo ? (
      <LiveBanner
        initialNow={Date.now()}
        persona={current.name ?? 'Demo persona'}
        surface={current.lab?.surface}
        sandbox={current.lab?.sandbox}
        generation={current.lab?.generation}
        resetsAt={current.lab?.resetsAt}
        mode={current.lab?.mode}
      />
    ) : null
    return (
      <Document title={`${title} · Big Buck`}>
        {bare ? (
          children
        ) : (
          <div class={current?.demo ? 'demo-frame' : undefined}>
            {demoBanner}
            <div class="app-shell" data-layout={wide ? 'wide' : 'app'}>
              <a class="skip-link" href="#main">
                Skip to content
              </a>
              <AppNav orgQuery={orgQuery} />
              <main id="main" class="app-main">
                <header class="page-head">
                  <div>
                    {backHref ? (
                      <a class="back-link" href={backHref}>
                        ← {backLabel ?? 'Back'}
                      </a>
                    ) : null}
                    {/* With a back link, the link already says where this page sits ("← Jobs"), so the
                        type label ("Job") would only repeat it above the title. */}
                    {eyebrow && !backHref ? <p class="eyebrow">{eyebrow}</p> : null}
                    {handle.props.titleActions ? (
                      <div class="page-title-line">
                        <h1>{title}</h1>
                        {handle.props.titleActions}
                      </div>
                    ) : (
                      <h1>{title}</h1>
                    )}
                    {sub ? <p class="sub">{sub}</p> : null}
                  </div>
                  <div class="page-head-aside">
                    {signedIn() ? <CommandBar commands={visibleCommands(commandList(orgQuery))} /> : null}
                    <CreateMenu orgQuery={orgQuery} />
                  </div>
                </header>
                {eyebrow === 'Settings' ? <SettingsNavigation orgQuery={orgQuery} /> : null}
                {children}
              </main>
            </div>
          </div>
        )}
      </Document>
    )
  }
}

export function SetupNeeded() {
  return () => (
    <Shell title="Sign in to continue" eyebrow="Session">
      <p class="sub mute">
        This page needs a signed-in member of an organization.{' '}
        <a href={routes.session.index.href()}>Sign in</a> to continue.
      </p>
    </Shell>
  )
}

/** A missing page or record, inside the normal app frame, with a way back. */
export function NotFoundPage(
  handle: Handle<{ title?: string; message?: string; href?: string; linkLabel?: string }>,
) {
  return () => {
    const signed = Boolean(signedIn())
    const {
      title = 'Page not found',
      message = 'This page does not exist, or the link is out of date.',
      href = signed ? routes.today.href() : routes.careersIndex.href(),
      linkLabel = signed ? 'Go to Today' : 'See open roles',
    } = handle.props
    return (
      <Shell title={title} eyebrow="Not found">
        <div class="empty stack">
          <p>{message}</p>
          <p>
            <a class="btn btn-ghost" href={href}>
              {linkLabel} →
            </a>
          </p>
        </div>
      </Shell>
    )
  }
}

export function Mute(handle: Handle<{ children?: RemixNode }>) {
  return () => <p class="sub mute">{handle.props.children}</p>
}

export function EmptyState(handle: Handle<{ children?: RemixNode }>) {
  return () => <div class="empty">{handle.props.children}</div>
}

export function RowList(handle: Handle<{ children?: RemixNode }>) {
  return () => <ul class="row-list">{handle.props.children}</ul>
}

export function RowLink(handle: Handle<{ href: string; title: string; meta?: string }>) {
  return () => {
    let { href, title, meta } = handle.props
    return (
      <li>
        <a href={href} class="row-link">
          <span class="row-link-title">{title}</span>
          {meta ? <span class="row-link-meta">{meta}</span> : null}
        </a>
      </li>
    )
  }
}

export function PrimaryButton(handle: Handle<{ type?: 'submit' | 'button'; children?: RemixNode }>) {
  return () => (
    <button type={handle.props.type ?? 'button'} class="btn btn-primary">
      {handle.props.children}
    </button>
  )
}

export function Field(
  handle: Handle<{
    label: string
    name: string
    id?: string
    email?: boolean
    required?: boolean
    defaultValue?: string
    placeholder?: string
  }>,
) {
  return () => {
    let { label, name, email, required, defaultValue } = handle.props
    return (
      <label class="field">
        <span>{label}</span>
        {email ? (
          <input
            id={handle.props.id ?? `field-${name}`}
            name={name}
            type="email"
            required={required}
            placeholder={handle.props.placeholder}
            defaultValue={defaultValue}
          />
        ) : (
          <input
            id={handle.props.id ?? `field-${name}`}
            name={name}
            type="text"
            required={required}
            placeholder={handle.props.placeholder}
            defaultValue={defaultValue}
          />
        )}
      </label>
    )
  }
}
