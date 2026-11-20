import { createController } from 'remix/router'

import { signIn, signOut, signedIn } from '../../data/auth.ts'
import {
  createSession,
  exchangeSessionCode,
  googleOauthStartHref,
  googleOauthStatus,
  listDemoMemberships,
  revokeSession,
  type DemoMembership,
  type SessionResponse,
} from '../../data/api.ts'
import { refreshViewer } from '../../data/viewer.ts'
import { routes } from '../../routes.ts'
import { entry } from '../lab/controller.tsx'
import { SessionPage } from './pages.tsx'

async function remember(session: SessionResponse, demo = false) {
  signIn({
    token: session.session.token,
    email: session.user.email,
    name: session.user.name,
    organizationId: session.organization.id,
    organizationSlug: session.organization.slug,
    demo,
  })
  await refreshViewer({ token: session.session.token })
}

function seeOther(location: string) {
  return new Response(null, { status: 303, headers: { Location: location } })
}

async function googleHrefFor(slug: string) {
  const status = await googleOauthStatus().catch(() => ({ configured: false as const }))
  return status.configured ? googleOauthStartHref({ slug, returnTo: '/session' }) : null
}

export default createController(routes.session, {
  actions: {
    async index(context) {
      const url = new URL(context.request.url)
      const slug = url.searchParams.get('slug') ?? 'big-buck'
      const code = url.searchParams.get('code')
      const oauthError = url.searchParams.get('error')

      // Google sign-in lands here with a one-time code; trade it server-side.
      if (code) {
        try {
          await remember(await exchangeSessionCode(code), false)
          return seeOther(routes.today.href())
        } catch {
          return context.render(
            <SessionPage error="That sign-in link has expired. Please sign in again." googleHref={await googleHrefFor(slug)} defaultSlug={slug} />,
          )
        }
      }

      if (!code && !oauthError) return entry(context)
      const current = signedIn()
      const roles = await listDemoMemberships(slug).catch(() => ({ data: [] as DemoMembership[] }))
      return context.render(
        <SessionPage
          error={oauthError ?? undefined}
          notice={current ? `Signed in as ${current.email ?? current.name}` : undefined}
          redirectHint={current ? routes.home.href() : undefined}
          signedInAs={current?.email}
          googleHref={await googleHrefFor(slug)}
          defaultSlug={slug}
          roles={roles.data}
        />,
      )
    },
    async action(context) {
      const form = await context.request.formData()

      if (String(form.get('intent') ?? '') === 'sign-out') {
        const current = signedIn()
        if (current) await revokeSession({ token: current.token })
        signOut()
        return seeOther(routes.session.index.href())
      }

      const email = String(form.get('email') ?? '').trim()
      const slug = String(form.get('slug') ?? '').trim()
      const organizationId = String(form.get('organization_id') ?? '').trim()
      try {
        const session = await createSession({
          email,
          ...(organizationId ? { organization_id: organizationId } : { slug }),
        })
        await remember(session, true)
        return seeOther(routes.today.href())
      } catch (error) {
        return context.render(
          <SessionPage error={String(error)} googleHref={await googleHrefFor(slug || 'big-buck')} defaultSlug={slug} />,
        )
      }
    },
  },
})
