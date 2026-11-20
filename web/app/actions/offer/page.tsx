import type { Handle } from 'remix/component'
import { css, unsafeHTML } from 'remix/component'

import { formatWhen } from '../../data/hubs.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { CandidateFrame } from '../../ui/candidate-frame.tsx'
import { Field, Mute, PrimaryButton } from '../../ui/shell.tsx'

export const DECLINE_REASONS = [
  ['accepted_other_offer', 'I accepted another offer'],
  ['compensation', 'Compensation'],
  ['role_fit', 'The role is not the right fit'],
  ['timing', 'Timing'],
  ['other', 'Another reason'],
] as const

export type OfferPageProps = {
  token: string
  status: string
  letterHtml?: string
  usable: boolean
  expiresAt?: string
  error?: string
  /** The candidate just answered: accepted or declined. */
  answered?: 'accepted' | 'declined'
  hired?: boolean
  typedName?: string
  orgName?: string
  slug?: string
  demo?: boolean
  canAccept?: boolean
  canDecline?: boolean
}

export function OfferPage(handle: Handle<OfferPageProps>) {
  return () => {
    let props = handle.props
    let canAccept = props.canAccept ?? true
    let canDecline = props.canDecline ?? true
    let open = props.usable && props.status === 'sent'
    return (
      <CandidateFrame title="Your offer" orgName={props.orgName} slug={props.slug} kicker="Offer">
        {props.answered === 'accepted' ? (
          <div class="candidate-success" role="status">
            <h2>Offer accepted</h2>
            <p>
              Thank you{props.typedName ? `, ${props.typedName}` : ''}. Your acceptance is recorded
              {props.hired ? ' and you are marked as hired' : ''}. The recruiting team will be in touch about
              next steps.
            </p>
          </div>
        ) : props.answered === 'declined' ? (
          <div class="candidate-success" role="status">
            <h2>Answer recorded</h2>
            <p>
              You declined this offer. Thank you for letting us know. The recruiting team has been notified.
            </p>
          </div>
        ) : (
          <>
            <Mute>
              Status: {label(props.status)}
              {props.expiresAt ? (
                <>
                  {' '}
                  · Expires <time dateTime={props.expiresAt}>{formatWhen(props.expiresAt)}</time>
                </>
              ) : null}
            </Mute>
            {props.demo ? (
              <p class="demo-disclaimer" role="note">
                Demo offer for an invented company. Answering it updates the demo workspace only.
              </p>
            ) : null}
            {props.letterHtml ? (
              <div
                role="region"
                aria-label="Offer letter"
                tabIndex={0}
                mix={css({
                  overflow: 'auto',
                  margin: '24px 0',
                  padding: '20px 0',
                  borderTop: '1px solid var(--bb-border)',
                  borderBottom: '1px solid var(--bb-border)',
                  lineHeight: 1.6,
                })}
                innerHTML={unsafeHTML(props.letterHtml)}
              />
            ) : null}
            {props.error ? (
              <p class="notice-bad" role="alert">
                {props.error}
              </p>
            ) : null}
            {!open ? (
              <Mute>
                {props.usable
                  ? `This offer is ${label(props.status).toLowerCase()}; there is nothing to answer.`
                  : 'This link is no longer usable. Ask your recruiting team for a current link.'}
              </Mute>
            ) : !canAccept && !canDecline ? (
              <Mute>
                Answers to this offer are turned off in this demo. The recruiting team records it instead.
              </Mute>
            ) : (
              <div class="offer-answer">
                {canAccept ? (
                  <form method="post" action={routes.offer.action.href({ token: props.token })}>
                    <input type="hidden" name="intent" value="accept" />
                    <Field
                      label="Type your full name to accept"
                      name="typed_name"
                      defaultValue={props.typedName}
                      required
                    />
                    <PrimaryButton type="submit">Accept offer</PrimaryButton>
                  </form>
                ) : null}
                {canDecline ? (
                  <details class="offer-decline">
                    <summary>Decline this offer</summary>
                    <form method="post" action={routes.offer.action.href({ token: props.token })}>
                      <input type="hidden" name="intent" value="decline" />
                      <label class="field">
                        <span>Reason (optional)</span>
                        <select name="reason_key">
                          <option value="">Prefer not to say</option>
                          {DECLINE_REASONS.map(([value, text]) => (
                            <option key={value} value={value}>
                              {text}
                            </option>
                          ))}
                        </select>
                      </label>
                      <button class="btn btn-ghost" type="submit">
                        Decline offer
                      </button>
                    </form>
                  </details>
                ) : null}
              </div>
            )}
          </>
        )}
      </CandidateFrame>
    )
  }
}

/** A sentence a candidate can act on, never an API error string. */
export function candidateError(error: unknown, action: 'accept' | 'decline'): string {
  const message = error instanceof Error ? error.message : String(error)
  if (message.includes('turned off in this demo'))
    return 'Answers to offers are turned off in this demo workspace.'
  if (/expired|not usable|no longer/i.test(message))
    return 'This offer link has expired or was already used. Ask your recruiting team for a current link.'
  if (message.includes('typed_name')) return 'Type your full name exactly to accept.'
  return `We could not ${action} the offer just now. Please try again, or contact the recruiting team.`
}
