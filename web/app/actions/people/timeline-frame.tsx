import type { Handle } from 'remix/component'

import type { TimelineEvent } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { Mute } from '../../ui/shell.tsx'

/** A readable line for an event: its own summary when it has one, never a raw payload. */
function summary(event: TimelineEvent): string | null {
  const text = event.payload?.summary
  return typeof text === 'string' && text.trim() ? text.trim() : null
}

/** Frame-friendly timeline slice for person dossier. */
export function PersonTimelineFrame(handle: Handle<{ events: TimelineEvent[] }>) {
  return () => {
    let { events } = handle.props
    if (events.length === 0) return <Mute>No timeline events yet.</Mute>
    return (
      <ol class="record-timeline">
        {events.map((event) => (
          <li key={event.id}>
            <strong>{label(event.event_type.replace(/\./g, '_'))}</strong>
            {summary(event) ? <span class="sub"> {summary(event)}</span> : null}
            {event.occurred_at ? (
              <time dateTime={event.occurred_at}>
                {new Date(event.occurred_at).toLocaleString('en-US', {
                  timeZone: 'America/New_York',
                  timeZoneName: 'short',
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric',
                  hour: 'numeric',
                  minute: '2-digit',
                })}
              </time>
            ) : null}
          </li>
        ))}
      </ol>
    )
  }
}
