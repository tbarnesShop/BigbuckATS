import type { Handle } from 'remix/component'

import { routes } from '../../routes.ts'
import { CandidateFrame } from '../../ui/candidate-frame.tsx'
import { Mute, PrimaryButton } from '../../ui/shell.tsx'

export type UnsubscribePageProps = {
  token: string
  orgName?: string
  emailHint?: string
  /** The address is opted out: either just now or earlier. */
  done?: boolean
  error?: string
}

export function UnsubscribePage(handle: Handle<UnsubscribePageProps>) {
  return () => {
    let props = handle.props
    return (
      <CandidateFrame title="Unsubscribe" orgName={props.orgName} kicker="Email preferences">
        {props.error ? (
          <p class="candidate-error" role="alert">
            {props.error}
          </p>
        ) : props.done ? (
          <div class="candidate-success" role="status">
            <h2>You are unsubscribed</h2>
            <p>
              {props.orgName ?? 'The recruiting team'} will not email {props.emailHint ?? 'you'} again.
            </p>
          </div>
        ) : (
          <form method="post" action={routes.unsubscribe.action.href({ token: props.token })}>
            <p>
              Stop all email from {props.orgName ?? 'this recruiting team'} to {props.emailHint}?
            </p>
            <PrimaryButton type="submit">Unsubscribe</PrimaryButton>
            <Mute>You can still apply to roles yourself at any time.</Mute>
          </form>
        )}
      </CandidateFrame>
    )
  }
}
