import { clientEntry, ref } from 'remix/component'

/**
 * Drag-and-drop for server-rendered lists. It only fills and submits a form the page already has,
 * so the move goes through the same action as the buttons and links, which stay as the keyboard,
 * touch and no-script path.
 *
 * Markup contract, inside one `[data-drag-root]`:
 *   - `data-drag-root="board"`: dropping an item on another `[data-drop-zone]` submits that zone's
 *     `data-drop-value`. `data-drag-root="sort"`: dropping reorders within the list and submits the new index.
 *   - `[data-drag-item][data-drag-id]`: what can be picked up.
 *   - `[data-drop-zone]` holding a `[data-drop-list]` (or being one): where items land.
 *   - `form[data-drag-form]` with inputs named `drag_id` and `drag_to`.
 */
export const DragMove = clientEntry(import.meta.url, function DragMove() {
  return () => (
    <span
      hidden
      mix={ref((node: HTMLSpanElement, signal) => {
        const root = node.closest<HTMLElement>('[data-drag-root]')
        const form = root?.querySelector<HTMLFormElement>('form[data-drag-form]')
        if (!root || !form) return
        const sort = root.dataset.dragRoot === 'sort'
        const idField = form.elements.namedItem('drag_id') as HTMLInputElement | null
        const toField = form.elements.namedItem('drag_to') as HTMLInputElement | null
        if (!idField || !toField) return

        const items = () => [...root.querySelectorAll<HTMLElement>('[data-drag-item]')]
        for (const item of items()) {
          item.draggable = true
          // A link or image inside the card would otherwise be dragged instead of the card.
          for (const inner of item.querySelectorAll<HTMLElement>('a, img')) inner.draggable = false
        }
        root.dataset.dragReady = 'true'

        let dragged: HTMLElement | null = null
        let submitted = false
        const zoneOf = (target: EventTarget | null) =>
          target instanceof Element ? target.closest<HTMLElement>('[data-drop-zone]') : null
        const listOf = (zone: HTMLElement) =>
          zone.matches('[data-drop-list]') ? zone : zone.querySelector<HTMLElement>('[data-drop-list]')
        const clearMarks = () => {
          for (const marked of root.querySelectorAll('[data-drop-active], [data-drop-edge]')) {
            marked.removeAttribute('data-drop-active')
            marked.removeAttribute('data-drop-edge')
          }
        }
        // The sibling the dragged item would be inserted before, or null for the end of the list.
        const before = (list: HTMLElement, y: number) => {
          const others = [...list.querySelectorAll<HTMLElement>('[data-drag-item]')].filter(
            (item) => item !== dragged,
          )
          return (
            others.find((item) => {
              const box = item.getBoundingClientRect()
              return y < box.top + box.height / 2
            }) ?? null
          )
        }

        root.addEventListener(
          'dragstart',
          (event) => {
            const item =
              event.target instanceof Element ? event.target.closest<HTMLElement>('[data-drag-item]') : null
            if (!item || submitted || !root.contains(item)) return
            dragged = item
            event.dataTransfer?.setData('text/plain', item.dataset.dragId ?? '')
            if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
            // Mark after the browser has taken its drag image, so the image is not dimmed.
            requestAnimationFrame(() => item.setAttribute('data-dragging', 'true'))
          },
          { signal },
        )
        root.addEventListener(
          'dragover',
          (event) => {
            const zone = zoneOf(event.target)
            if (!dragged || !zone) return
            event.preventDefault()
            if (event.dataTransfer) event.dataTransfer.dropEffect = 'move'
            clearMarks()
            zone.setAttribute('data-drop-active', 'true')
            if (!sort) return
            const list = listOf(zone)
            if (!list) return
            const next = before(list, event.clientY)
            if (next) next.setAttribute('data-drop-edge', 'before')
            else
              [...list.querySelectorAll<HTMLElement>('[data-drag-item]')]
                .findLast((item) => item !== dragged)
                ?.setAttribute('data-drop-edge', 'after')
          },
          { signal },
        )
        root.addEventListener(
          'dragleave',
          (event) => {
            if (!root.contains(event.relatedTarget as Node | null)) clearMarks()
          },
          { signal },
        )
        root.addEventListener(
          'dragend',
          () => {
            dragged?.removeAttribute('data-dragging')
            dragged = null
            clearMarks()
          },
          { signal },
        )
        root.addEventListener(
          'drop',
          (event) => {
            const zone = zoneOf(event.target)
            const item = dragged
            if (!item || !zone) return
            event.preventDefault()
            const list = listOf(zone)
            if (!list) return
            let to: string
            if (sort) {
              const order = [...list.querySelectorAll<HTMLElement>('[data-drag-item]')]
              const from = order.indexOf(item)
              const next = before(list, event.clientY)
              list.insertBefore(item, next)
              const index = [...list.querySelectorAll<HTMLElement>('[data-drag-item]')].indexOf(item)
              if (index === from) return
              to = String(index)
            } else {
              if (item.closest('[data-drop-zone]') === zone) return
              list.append(item)
              to = zone.dataset.dropValue ?? ''
            }
            // Show the move at once; the page that comes back is the saved state.
            submitted = true
            root.setAttribute('aria-busy', 'true')
            idField.value = item.dataset.dragId ?? ''
            toField.value = to
            form.requestSubmit()
          },
          { signal },
        )
      })}
    />
  )
})
