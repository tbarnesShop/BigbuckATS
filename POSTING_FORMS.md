# Posting application forms

Organization-wide required fields and screening/compliance questions remain the mandatory first section of every form. Recruiters cannot remove those questions from a posting.

A job can have multiple postings, each with its own title, public/internal/both audience, publication state, template snapshot, and additional questions. Audience is enforced against the selected posting at listing and submission time.

Question templates belong to their creator. Organization members with job.read can reuse templates; the owner or a settings administrator can edit/archive them. Choosing a template copies its questions into the posting, so later template edits do not affect existing forms. Posting questions follow template questions. Duplicate question keys within each layer are rejected; template and posting keys use separate namespaces.

Applications retain the posting ID and the submitted question definitions and typed answers. Existing organization custom-field answers continue to be written to custom-field values. Posting-specific answers do not become organization-wide fields.

The existing job-level careers settings remain bulk controls for legacy callers. New recruiter operations use the per-posting workspace. A migration assigns existing postings their job's audience, preserving public/internal/hidden behavior.

Recruiter entry points: Job → Settings → Manage postings and questions, and Settings → Question templates. The editor previews the three question layers and links to each published application form. Application responses are shown on the recruiter application page using the submitted labels, included in candidate access packets, and cleared during erasure/anonymization.

REST management uses `GET/POST /v1/jobs/:job_id/postings`, `PATCH /v1/postings/:id`, and `GET/POST/PATCH /v1/application_question_templates[/:id]`. Send `expected_version` when editing to detect stale changes. Selecting `question_template_id` copies its current questions; omit it to preserve the saved copy or send null to remove that copy.

Application answers use organization field keys followed by `template.<key>` and `posting.<key>`. Choice answers must match the configured options; multi-select answers are arrays. Public/internal careers entries include the exact posting ID and composed form. Existing job apply URLs remain usable; `?posting_id=...` selects a specific posting when the job has multiple openings.
