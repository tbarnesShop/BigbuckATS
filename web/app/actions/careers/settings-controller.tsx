import { createController } from 'remix/router'

import {
  getPublicCareers,
  sessionFromEnv,
  sessionFromRequest,
  updateOrganizationCareers,
} from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { careersSlugFrom, orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { CareersSettingsPage } from './settings-page.tsx'

export default createController(routes.careersSettings, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      const slug = careersSlugFrom(context.url)
      if (!session || !slug) return context.render(<SetupNeeded />)
      try {
        const careers = await getPublicCareers(slug)
        return context.render(
          <CareersSettingsPage careers={careers} orgQuery={orgQuery(context.url)} />,
        )
      } catch (error) {
        return new Response(`Careers settings error: ${String(error)}`, { status: 502 })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      const slug = careersSlugFrom(context.url)
      if (!session || !slug) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      try {
        const organizationId = signedIn()?.organizationId ?? (await getPublicCareers(slug)).organization.id
        await updateOrganizationCareers(session, organizationId, {
          careers_hero_image_url: String(form.get('careers_hero_image_url') ?? '').trim() || undefined,
          careers_headline: String(form.get('careers_headline') ?? '').trim() || undefined,
          careers_subcopy: String(form.get('careers_subcopy') ?? '').trim() || undefined,
        })
        const careers = await getPublicCareers(slug)
        return context.render(
          <CareersSettingsPage
            careers={careers}
            orgQuery={orgQuery(context.url)}
            notice="Careers branding saved"
          />,
        )
      } catch (error) {
        try {
          const careers = await getPublicCareers(slug)
          return context.render(
            <CareersSettingsPage
              careers={careers}
              orgQuery={orgQuery(context.url)}
              error={String(error)}
            />,
          )
        } catch {
          return new Response(String(error), { status: 502 })
        }
      }
    },
  },
})
