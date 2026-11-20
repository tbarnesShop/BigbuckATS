import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import { formatWhen } from '../../data/hubs.ts'
import { CandidateFrame } from '../../ui/candidate-frame.tsx'
import { Mute } from '../../ui/shell.tsx'

export function SchedulingPublicPage(
  handle: Handle<{
    token: string
    link: {
      usable: boolean
      kind: string
      expires_at?: string
      organization?: { name: string; slug?: string }
      application?: { job_title?: string; person_name?: string }
    }
  }>,
) {
  return () => {
    let { link } = handle.props
    return (
      <CandidateFrame
        title="Schedule interview"
        orgName={link.organization?.name}
        slug={link.organization?.slug}
        kicker="Schedule"
      >
        <Mute>
          {link.application?.person_name ?? 'Candidate'} · {link.application?.job_title ?? 'Role'}
        </Mute>
        <p mix={css({ fontSize: '16px', lineHeight: 1.5, maxWidth: '32rem' })}>
          {link.usable
            ? 'This scheduling link is active. Your recruiting team will share available times when interview calendars are ready.'
            : 'This link is no longer usable (expired, revoked, or already used).'}
        </p>
        <p mix={css({ marginTop: '16px', color: 'var(--bb-text-muted)', fontSize: '14px' })}>
          {link.usable ? 'Link active' : 'Link unavailable'}
          {link.expires_at ? (
            <>
              {' '}
              · Expires <time dateTime={link.expires_at}>{formatWhen(link.expires_at)}</time>
            </>
          ) : null}
        </p>
      </CandidateFrame>
    )
  }
}
