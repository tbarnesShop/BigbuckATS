import { createController } from 'remix/router'

import {
  approveOffer,
  createApplicationTransition,
  getJob,
  getOffer,
  getPerson,
  recordOfferResponse,
  rescindOffer,
  resendOffer,
  sendOffer,
  sessionFromEnv,
  sessionFromRequest,
  submitOffer,
  updateOfferChecklist,
} from '../../data/api.ts'
import { redirectWithNotice, takeWorkflowNotice } from '../../data/auth.ts'
import { gql } from '../../data/graphql.ts'
import type { ViewerQuery } from '../../graphql/generated.ts'
import { workflowError } from '../../data/application-workflow.ts'
import { label } from '../../data/labels.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { OfferShowPage } from './pages.tsx'

async function load(
  session: NonNullable<ReturnType<typeof sessionFromRequest>>,
  offerId: string,
  orgQueryStr: string,
  extras?: { notice?: string; error?: string; sendToken?: string },
) {
  const offer = await getOffer(session, offerId)
  let personName: string | undefined
  let jobTitle: string | undefined
  let approverNames: Record<string, string> = {}
  try {
    if (offer.application?.person_id) {
      const person = await getPerson(session, offer.application.person_id)
      personName = person.display_name
    }
  } catch {
    /* optional enrichment */
  }
  try {
    if (offer.application?.job_id) {
      const job = await getJob(session, offer.application.job_id)
      jobTitle = job.title
      approverNames = Object.fromEntries(
        (job.hiring_team ?? []).map((member) => [member.user_id, member.name ?? 'Assigned approver']),
      )
    }
  } catch {
    /* optional enrichment */
  }
  const viewer = await gql<ViewerQuery>(session, 'Viewer')
  return (
    <OfferShowPage
      offer={offer}
      orgQuery={orgQueryStr}
      personName={personName}
      jobTitle={jobTitle}
      approverNames={approverNames}
      canApprove={(offer.pending_approvals ?? []).some(
        (step) => step.approver_user_id === viewer.viewer.user?.id,
      )}
      notice={extras?.notice}
      error={extras?.error}
      sendToken={extras?.sendToken}
    />
  )
}

export default createController(routes.offersShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        return context.render(
          await load(session, context.params.offerId, orgQuery(context.url), {
            notice: takeWorkflowNotice(),
          }),
        )
      } catch {
        return new Response('Offer not found', { status: 404 })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      const complete = (notice: string) =>
        redirectWithNotice(
          `${routes.offersShow.index.href({ offerId: context.params.offerId })}${orgQuery(context.url)}`,
          notice,
        )
      try {
        if (intent === 'submit') {
          await submitOffer(session, context.params.offerId)
          return complete('Submitted for approval')
        }
        if (intent === 'approve') {
          await approveOffer(session, context.params.offerId, false)
          return complete('Approved')
        }
        if (intent === 'override') {
          await approveOffer(session, context.params.offerId, true)
          return complete('Approved with an owner override.')
        }
        if (intent === 'hire') {
          const offer = await getOffer(session, context.params.offerId)
          await createApplicationTransition(session, offer.application_id, { command: 'hire' })
          return complete('Candidate marked hired.')
        }
        if (intent === 'checklist') {
          const item = String(form.get('item') ?? '')
          if (item !== 'references' && item !== 'verbal') throw new Error('Unknown checklist step')
          const state = String(form.get('state') ?? '')
          const note = String(form.get('note') ?? '').trim()
          await updateOfferChecklist(session, context.params.offerId, {
            item,
            state,
            ...(note ? { note } : {}),
          })
          return complete(
            item === 'references' ? `References: ${label(state)}.` : `Verbal offer: ${label(state)}.`,
          )
        }
        if (intent === 'send') {
          const sent = await sendOffer(session, context.params.offerId, {
            to_email: String(form.get('to_email') ?? '') || undefined,
          })
          return context.render(
            await load(session, context.params.offerId, orgQuery(context.url), {
              notice: 'Offer sent',
              sendToken: sent.send?.token,
            }),
          )
        }
        if (intent === 'resend') {
          const sent = await resendOffer(session, context.params.offerId)
          return context.render(
            await load(session, context.params.offerId, orgQuery(context.url), {
              notice: `Offer resent${sent.send?.to_email ? ` to ${sent.send.to_email}` : ''}. A fresh signing link is below.`,
              sendToken: sent.send?.token,
            }),
          )
        }
        if (intent === 'record_response') {
          const response = String(form.get('response') ?? '')
          if (response !== 'accepted' && response !== 'declined')
            throw new Error("Choose the candidate's answer")
          const note = String(form.get('note') ?? '').trim()
          const recorded = await recordOfferResponse(session, context.params.offerId, {
            response,
            note: note || undefined,
          })
          return complete(
            recorded.hired
              ? 'Acceptance recorded. The candidate is hired.'
              : response === 'accepted'
                ? 'Acceptance recorded. Open the candidate to mark them hired.'
                : 'Decline recorded.',
          )
        }
        if (intent === 'rescind') {
          await rescindOffer(session, context.params.offerId, String(form.get('reason_key') || 'rescinded'))
          return complete('Offer rescinded')
        }
        throw new Error(`Unknown intent ${intent}`)
      } catch (error) {
        try {
          return context.render(
            await load(session, context.params.offerId, orgQuery(context.url), {
              error: `Could not save: ${workflowError(error)}`,
            }),
          )
        } catch {
          return new Response(String(error), { status: 502 })
        }
      }
    },
  },
})
