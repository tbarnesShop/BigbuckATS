import { createController } from 'remix/router'

import { confirmPublicUnsubscribe, getPublicUnsubscribe } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { UnsubscribePage } from './page.tsx'

const UNAVAILABLE = 'This unsubscribe link is not valid. Reply to the email and ask to be removed.'

export default createController(routes.unsubscribe, {
  actions: {
    async index(context) {
      const token = context.params.token
      try {
        const info = await getPublicUnsubscribe(token)
        return context.render(
          <UnsubscribePage
            token={token}
            orgName={info.organization.name}
            emailHint={info.email_hint}
            done={info.already_unsubscribed}
          />,
        )
      } catch {
        const response = await context.render(<UnsubscribePage token={token} error={UNAVAILABLE} />)
        return new Response(response.body, { status: 404, headers: response.headers })
      }
    },
    async action(context) {
      const token = context.params.token
      try {
        const info = await getPublicUnsubscribe(token)
        await confirmPublicUnsubscribe(token)
        return context.render(
          <UnsubscribePage token={token} orgName={info.organization.name} emailHint={info.email_hint} done />,
        )
      } catch {
        return context.render(<UnsubscribePage token={token} error={UNAVAILABLE} />)
      }
    },
  },
})
