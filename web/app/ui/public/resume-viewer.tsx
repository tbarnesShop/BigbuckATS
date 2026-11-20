import { clientEntry, ref, type Handle } from 'remix/component'

/** Render PDF pages ourselves so mobile and desktop use the same in-app viewer. */
export const ResumeViewer = clientEntry(
  import.meta.url,
  function ResumeViewer(
    handle: Handle<{
      href: string
      filename: string
      contentType: string
      expanded?: boolean
      /** Served URLs for pdf.js's worker, standard fonts and character maps (app/assets.ts pdfjsUrls). */
      pdfjs: { worker: string; fonts: string; cmaps: string }
    }>,
  ) {
    return () => (
      <details
        class="resume-viewer"
        data-fixed={handle.props.expanded ? 'true' : undefined}
        open={handle.props.expanded}
        mix={ref((details: HTMLDetailsElement, signal) => {
          const panel = details.querySelector<HTMLElement>('.resume-preview')!
          const status = details.querySelector<HTMLElement>('[role="status"]')!
          const pageLabel = details.querySelector<HTMLElement>('.resume-page-label')!
          const previous = details.querySelector<HTMLButtonElement>('[data-page="previous"]')!
          const next = details.querySelector<HTMLButtonElement>('[data-page="next"]')!
          let pdf: import('pdfjs-dist').PDFDocumentProxy | undefined
          let loading: import('pdfjs-dist').PDFDocumentLoadingTask | undefined
          let rendering: import('pdfjs-dist').RenderTask | undefined
          let textLayer: import('pdfjs-dist').TextLayer | undefined
          let pageNumber = 1
          let zoom = 1
          let generation = 0
          let started = false
          const show = async () => {
            if (!pdf || !details.open) return
            const current = ++generation
            rendering?.cancel()
            textLayer?.cancel()
            status.textContent = 'Loading resume page…'
            try {
              const page = await pdf.getPage(pageNumber)
              if (signal.aborted || current !== generation) return
              const base = page.getViewport({ scale: 1 })
              const scale = Math.max(0.1, (panel.clientWidth - 2) / base.width) * zoom
              const viewport = page.getViewport({ scale })
              const sheet = document.createElement('div')
              sheet.className = 'resume-sheet'
              sheet.style.width = `${viewport.width}px`
              sheet.style.height = `${viewport.height}px`
              sheet.style.setProperty('--scale-factor', String(scale))
              sheet.style.setProperty('--total-scale-factor', String(scale))
              const canvas = document.createElement('canvas')
              canvas.setAttribute('aria-label', `${handle.props.filename}, page ${pageNumber}`)
              canvas.setAttribute('role', 'img')
              const ratio = Math.min(devicePixelRatio || 1, 2)
              canvas.width = Math.ceil(viewport.width * ratio)
              canvas.height = Math.ceil(viewport.height * ratio)
              canvas.style.width = `${viewport.width}px`
              canvas.style.height = `${viewport.height}px`
              const text = document.createElement('div')
              text.className = 'textLayer'
              sheet.append(canvas, text)
              panel.replaceChildren(sheet)
              rendering = page.render({ canvas, viewport, transform: [ratio, 0, 0, ratio, 0, 0] })
              await rendering.promise
              if (signal.aborted || current !== generation) return
              const { TextLayer } = await import('pdfjs-dist')
              const textContent = await page.getTextContent()
              if (signal.aborted || current !== generation) return
              textLayer = new TextLayer({
                textContentSource: textContent,
                container: text,
                viewport,
              })
              await textLayer.render()
              if (signal.aborted || current !== generation) return
              pageLabel.textContent = `Page ${pageNumber} of ${pdf.numPages}`
              previous.disabled = pageNumber === 1
              next.disabled = pageNumber === pdf.numPages
              status.textContent = ''
            } catch (error) {
              if (
                signal.aborted ||
                current !== generation ||
                (error as Error).name === 'RenderingCancelledException'
              )
                return
              status.textContent = handle.props.expanded
                ? 'Resume could not display. Refresh to try again, or download the file.'
                : 'Resume could not display. Close and reopen to try again, or download the file.'
            }
          }
          const open = async () => {
            if (!details.open) return
            if (started) {
              await show()
              return
            }
            started = true
            status.textContent = 'Loading resume…'
            try {
              if (handle.props.contentType === 'text/plain') {
                const response = await fetch(handle.props.href, { signal, credentials: 'same-origin' })
                if (!response.ok) throw new Error('File unavailable')
                const text = document.createElement('pre')
                text.textContent = await response.text()
                if (signal.aborted) return
                panel.replaceChildren(text)
                status.textContent = ''
                return
              }
              const { getDocument, GlobalWorkerOptions } = await import('pdfjs-dist')
              if (signal.aborted) return
              GlobalWorkerOptions.workerSrc = handle.props.pdfjs.worker
              loading = getDocument({
                url: handle.props.href,
                standardFontDataUrl: handle.props.pdfjs.fonts,
                cMapUrl: handle.props.pdfjs.cmaps,
                cMapPacked: true,
              })
              pdf = await loading.promise
              if (signal.aborted) return
              await show()
            } catch {
              if (signal.aborted) return
              started = false
              status.textContent = handle.props.expanded
                ? 'Resume could not display. Refresh to try again, or download the file.'
                : 'Resume could not display. Close and reopen to try again, or download the file.'
            }
          }
          details.addEventListener(
            'toggle',
            () => {
              void open()
            },
            { signal },
          )
          previous.addEventListener(
            'click',
            () => {
              if (pageNumber > 1) {
                pageNumber--
                void show()
              }
            },
            { signal },
          )
          next.addEventListener(
            'click',
            () => {
              if (pdf && pageNumber < pdf.numPages) {
                pageNumber++
                void show()
              }
            },
            { signal },
          )
          for (const button of details.querySelectorAll<HTMLButtonElement>('[data-zoom]')) {
            button.addEventListener(
              'click',
              () => {
                zoom =
                  button.dataset.zoom === 'fit'
                    ? 1
                    : Math.max(0.5, Math.min(3, zoom + (button.dataset.zoom === 'in' ? 0.25 : -0.25)))
                void show()
              },
              { signal },
            )
          }
          let width = panel.clientWidth
          const observer = new ResizeObserver(() => {
            if (panel.clientWidth && width !== panel.clientWidth) {
              width = panel.clientWidth
              void show()
            }
          })
          observer.observe(panel)
          signal.addEventListener(
            'abort',
            () => {
              generation++
              observer.disconnect()
              rendering?.cancel()
              textLayer?.cancel()
              void loading?.destroy()
            },
            { once: true },
          )
          if (details.open) void open()
        })}
      >
        <summary class="btn btn-ghost">
          <span class="resume-viewer-open">View resume</span>
          <span class="resume-viewer-close">Close resume</span>
        </summary>
        <div class="resume-viewer-body">
          <div
            class="resume-toolbar"
            aria-label="Resume controls"
            hidden={handle.props.contentType !== 'application/pdf'}
          >
            <button
              type="button"
              class="btn btn-ghost"
              data-page="previous"
              aria-label="Previous resume page"
              disabled
            >
              ←
            </button>
            <span class="resume-page-label" aria-live="polite">
              Page —
            </span>
            <button
              type="button"
              class="btn btn-ghost"
              data-page="next"
              aria-label="Next resume page"
              disabled
            >
              →
            </button>
            <button type="button" class="btn btn-ghost" data-zoom="out" aria-label="Zoom resume out">
              −
            </button>
            <button type="button" class="btn btn-ghost" data-zoom="in" aria-label="Zoom resume in">
              +
            </button>
            <button type="button" class="btn btn-ghost" data-zoom="fit">
              Fit width
            </button>
          </div>
          <p role="status">Open the viewer to load the resume. If the viewer is unavailable, use Download.</p>
          <div
            class="resume-preview"
            role="region"
            aria-label={`Resume preview: ${handle.props.filename}`}
            tabIndex={0}
          />
        </div>
      </details>
    )
  },
)
