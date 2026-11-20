import { createController } from 'remix/router'

import { acceptPublicOffer, declinePublicOffer, getPublicOffer } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { candidateError, DECLINE_REASONS, OfferPage, type OfferPageProps } from './page.tsx'

async function current(token: string): Promise<OfferPageProps> {
  const offer = await getPublicOffer(token)
  return {
    token,
    status: offer.status,
    letterHtml: offer.letter_html,
    usable: offer.usable,
    expiresAt: offer.expires_at,
    orgName: offer.organization?.name,
    slug: offer.organization?.slug,
    demo: offer.demo,
    canAccept: offer.can_accept,
    canDecline: offer.can_decline,
  }
}

export default createController(routes.offer, {
  actions: {
    async index(context) {
      try {
        return context.render(<OfferPage {...await current(context.params.token)} />)
      } catch {
        const response = await context.render(
          <OfferPage
            token={context.params.token}
            status="Unavailable"
            usable={false}
            error="This offer could not be found. Ask your recruiting team for a current link."
          />,
        )
        return new Response(response.body, { status: 404, headers: response.headers })
      }
    },
    async action(context) {
      const form = await context.request.formData()
      const intent = form.get('intent') === 'decline' ? 'decline' : 'accept'
      const typedName = String(form.get('typed_name') ?? '').trim()
      const reason = String(form.get('reason_key') ?? '')
      let view: OfferPageProps
      try {
        view = await current(context.params.token)
      } catch {
        return context.render(
          <OfferPage
            token={context.params.token}
            status="Unavailable"
            usable={false}
            error="This offer could not be found. Ask your recruiting team for a current link."
          />,
        )
      }
      try {
        if (intent === 'decline') {
          const reasonKey = DECLINE_REASONS.some(([value]) => value === reason) ? reason : undefined
          const result = await declinePublicOffer(context.params.token, reasonKey)
          return context.render(
            <OfferPage {...view} status={result.status} usable={false} answered="declined" />,
          )
        }
        if (!typedName) return context.render(<OfferPage {...view} error="Type your full name to accept." />)
        const result = await acceptPublicOffer(context.params.token, typedName)
        return context.render(
          <OfferPage
            {...view}
            status={result.status}
            usable={false}
            answered="accepted"
            hired={result.hired}
            typedName={typedName}
          />,
        )
      } catch (error) {
        console.error(`Offer ${intent} failed`, error)
        return context.render(
          <OfferPage {...view} typedName={typedName} error={candidateError(error, intent)} />,
        )
      }
    },
  },
})
