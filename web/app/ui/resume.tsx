import type { Handle } from 'remix/component'

import type { PersonDocuments } from '../data/documents.ts'
import { signedIn } from '../data/auth.ts'
import { routes } from '../routes.ts'
import { Mute } from './shell.tsx'
import { pdfjsUrls } from '../assets.ts'
import { ResumeViewer } from './public/resume-viewer.tsx'

export function ResumeSection(
  handle: Handle<{
    personId: string
    documents?: PersonDocuments
    orgQuery: string
    expanded?: boolean
    uploadAction?: string
  }>,
) {
  return () => {
    const { personId, documents, orgQuery } = handle.props
    if (!documents || documents.status === 'omitted') return null
    return (
      <section class="record-section resume-section" aria-label="Resume">
        <h2>Resume</h2>
        {handle.props.uploadAction && signedIn()?.permissions?.includes('document.upload') ? (
          <form
            method="post"
            action={handle.props.uploadAction}
            encType="multipart/form-data"
            class="resume-upload"
          >
            <input type="hidden" name="intent" value="upload_resume" />
            <label class="field">
              <span>
                {documents.status === 'ready' && documents.data.length ? 'Replace resume' : 'Upload resume'}
              </span>
              <input type="file" name="resume" accept=".pdf,.txt,.docx" required />
            </label>
            <button class="btn btn-primary" type="submit">
              Upload resume
            </button>
            <p class="list-meta">PDF, text or Word · up to 10 MB. Uploading replaces the current resume.</p>
          </form>
        ) : null}
        {documents.status === 'failed' ? (
          <p class="notice-bad" role="status">
            Resume could not load. Refresh to try again.
          </p>
        ) : documents.status === 'ready' && documents.data.length ? (
          <ul class="resume-files">
            {documents.data.map((document) => {
              const href = `${routes.personDocument.href({ personId, documentId: document.id })}${orgQuery}`
              const format =
                document.content_type === 'application/pdf'
                  ? 'PDF'
                  : document.content_type === 'text/plain'
                    ? 'Text'
                    : 'Document'
              const status =
                document.scan_status === 'pending'
                  ? 'Security scan pending'
                  : document.scan_status === 'failed'
                    ? 'Security scan unavailable'
                    : document.scan_status === 'infected'
                      ? 'File blocked'
                      : 'File unavailable'
              return (
                <li key={document.id}>
                  <div class="resume-file-info">
                    <strong>{document.filename}</strong>
                    <span class="list-meta">
                      {format} · {Math.max(1, Math.round(document.byte_size / 1024))} KB
                      {!document.downloadable ? ` · ${status}` : ''}
                    </span>
                  </div>
                  {document.downloadable ? (
                    <div class="resume-actions">
                      <a
                        class="btn btn-ghost"
                        href={`${href}${orgQuery ? '&' : '?'}download=true`}
                        download
                        aria-label={`Download resume: ${document.filename}`}
                      >
                        Download
                      </a>
                    </div>
                  ) : null}
                  {document.downloadable &&
                  ['application/pdf', 'text/plain'].includes(document.content_type) ? (
                    <ResumeViewer
                      expanded={handle.props.expanded}
                      href={href}
                      filename={document.filename}
                      contentType={document.content_type}
                      pdfjs={pdfjsUrls}
                    />
                  ) : null}
                </li>
              )
            })}
          </ul>
        ) : (
          <Mute>No resume attached.</Mute>
        )}
      </section>
    )
  }
}
