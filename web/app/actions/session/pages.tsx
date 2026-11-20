import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import type { DemoMembership } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { Field, Mute, PrimaryButton, Shell } from '../../ui/shell.tsx'
import { Brand } from '../../ui/brand.tsx'
import { color, font, motion } from '../../ui/tokens.ts'

const DEMO_ROLES = [
  {
    email: 'admin@bigbuck.test',
    label: 'Admin',
    detail: 'All people · restricted visible',
  },
  {
    email: 'recruiter@bigbuck.test',
    label: 'Recruiter',
    detail: 'Public people only',
  },
  {
    email: 'hm@bigbuck.test',
    label: 'Hiring manager',
    detail: 'Engineering-scoped public',
  },
  {
    email: 'owner@bigbuck.test',
    label: 'Owner',
    detail: 'Org owner · full catalog',
  },
  {
    email: 'outsider@example.com',
    label: 'Non-member',
    detail: 'No membership · empty people',
  },
] as const

export function SessionPage(
  handle: Handle<{
    notice?: string
    error?: string
    redirectHint?: string
    signedInAs?: string
    googleHref?: string | null
    defaultSlug?: string
    roles?: DemoMembership[]
  }>,
) {
  return () => {
    let { notice, error, redirectHint, signedInAs, googleHref, defaultSlug, roles = [] } = handle.props
    let roleButtons =
      roles.length > 0
        ? roles.map((role) => ({
            email: role.email,
            label: role.role_name || role.name || role.email,
            detail: role.email,
          }))
        : DEMO_ROLES.map((role) => ({ email: role.email, label: role.label, detail: role.detail }))
    return (
      <Shell title="Sign in" eyebrow="Session" bare>
        <section
          mix={css({
            minHeight: '100dvh',
            boxSizing: 'border-box',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            padding: '32px 24px',
            '@media (max-width: 600px)': { padding: '24px 16px' },
            maxWidth: '480px',
            margin: '0 auto',
            background: `radial-gradient(700px 400px at 100% 0%, var(--bb-accent-subtle) 0%, transparent 55%), ${color.background}`,
          })}
        >
          <Brand href={routes.session.index.href()} class="login-brand" />
          <p
            mix={css({
              margin: '0 0 12px',
              textTransform: 'uppercase',
              letterSpacing: '0.14em',
              fontSize: '11px',
              color: color.textMuted,
            })}
          >
            {googleHref ? 'Google SSO' : 'Demo SSO'}
          </p>
          <h1
            mix={css({
              fontFamily: font.ui,
              fontSize: 'var(--bb-type-page)',
              fontWeight: 600,
              letterSpacing: '-0.03em',
              color: color.accent,
              margin: '0 0 12px',
            })}
          >
            Big Buck
          </h1>
          <Mute>
            {googleHref
              ? 'Sign in with your work account, or choose a demo role below.'
              : 'Choose a demo role to explore this workspace.'}
          </Mute>
          {notice ? (
            <p mix={css({ color: color.accent, fontWeight: 600, margin: '16px 0' })}>{notice}</p>
          ) : null}
          {error ? (
            <p role="alert" mix={css({ color: color.danger, margin: '16px 0' })}>
              {error}
            </p>
          ) : null}
          {redirectHint ? (
            <p mix={css({ margin: '12px 0 24px' })}>
              <a href={redirectHint} mix={css({ color: color.accent, fontWeight: 600 })}>
                Continue to home →
              </a>
            </p>
          ) : null}
          {signedInAs ? (
            <form method="post" action={routes.login.action.href()} mix={css({ margin: '0 0 24px' })}>
              <input type="hidden" name="intent" value="sign-out" />
              <button
                type="submit"
                mix={css({
                  background: 'none',
                  border: 'none',
                  padding: 0,
                  color: color.textMuted,
                  textDecoration: 'underline',
                  cursor: 'pointer',
                  font: 'inherit',
                })}
              >
                Sign out
              </button>
            </form>
          ) : null}
          {googleHref ? (
            <p mix={css({ margin: '20px 0 8px' })}>
              <a
                href={googleHref}
                mix={css({
                  display: 'inline-block',
                  padding: '12px 18px',
                  background: color.accent,
                  color: color.onAccent,
                  textDecoration: 'none',
                  fontWeight: 600,
                  letterSpacing: '-0.01em',
                })}
              >
                Continue with Google
              </a>
            </p>
          ) : null}

          <h2
            mix={css({
              fontSize: '14px',
              margin: '20px 0 8px',
              color: color.accent,
              letterSpacing: '0.04em',
              textTransform: 'uppercase',
            })}
          >
            Demo roles
          </h2>
          <ul
            aria-label="Demo roles"
            mix={css({
              listStyle: 'none',
              margin: '0 0 28px',
              padding: 0,
              borderTop: `1px solid ${color.border}`,
            })}
          >
            {roleButtons.map((role) => (
              <li key={role.email}>
                <form method="post" action={routes.login.action.href()}>
                  <input type="hidden" name="email" value={role.email} />
                  <input type="hidden" name="slug" value={defaultSlug ?? 'big-buck'} />
                  <button
                    type="submit"
                    mix={css({
                      appearance: 'none',
                      width: '100%',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'baseline',
                      flexWrap: 'wrap',
                      gap: '12px',
                      padding: '14px 0',
                      border: 'none',
                      borderBottom: `1px solid ${color.border}`,
                      background: 'transparent',
                      color: color.accent,
                      fontFamily: font.ui,
                      fontSize: '16px',
                      fontWeight: 600,
                      cursor: 'pointer',
                      textAlign: 'left',
                      transition: `padding-left ${motion.rowSettle}`,
                      '&:hover': { paddingLeft: '8px' },
                    })}
                  >
                    <span>{role.label}</span>
                    <span mix={css({ fontSize: '12px', fontWeight: 400, color: color.textMuted })}>
                      {role.detail}
                    </span>
                  </button>
                </form>
              </li>
            ))}
          </ul>

          <form method="post" action={routes.login.action.href()} mix={css({ marginTop: '8px' })}>
            <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: color.accent })}>Custom email</h2>
            <Field label="Work email" name="email" email required defaultValue="admin@bigbuck.test" />
            <Field label="Organization slug" name="slug" required defaultValue={defaultSlug ?? 'big-buck'} />
            <PrimaryButton type="submit">Sign in with email (demo)</PrimaryButton>
          </form>
          <p mix={css({ marginTop: '28px' })}>
            <a href={routes.home.href()} mix={css({ color: color.accent })}>
              ← Home
            </a>
          </p>
        </section>
      </Shell>
    )
  }
}
