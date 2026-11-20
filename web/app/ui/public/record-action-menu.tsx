import { clientEntry, ref } from 'remix/component'

/** Enhance the native disclosure without hydrating or replacing its forms. */
export const RecordActionBehavior = clientEntry(import.meta.url, function RecordActionBehavior() {
  return () => (
    <span
      hidden
      mix={ref((node: HTMLSpanElement, signal) => {
        const details = node.closest('details')!
        const trigger = details.querySelector('summary')!
        const close = () => {
          details.open = false
        }
        details.addEventListener(
          'keydown',
          (event) => {
            if (event.key === 'Escape' && details.open) {
              event.preventDefault()
              close()
              trigger.focus({ preventScroll: true })
            }
          },
          { signal },
        )
        details.addEventListener(
          'focusout',
          (event) => {
            if (event.relatedTarget && !details.contains(event.relatedTarget as Node)) close()
          },
          { signal },
        )
        document.addEventListener(
          'pointerdown',
          (event) => {
            if (!details.contains(event.target as Node)) close()
          },
          { signal },
        )
      })}
    />
  )
})
