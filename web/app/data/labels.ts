/** Human labels for stored values (statuses, roles, types). Never show snake_case to a recruiter. */

const KNOWN: Record<string, string> = {
  // offers
  draft: 'Draft',
  pending_approval: 'Waiting for approval',
  changes_requested: 'Changes requested',
  approved: 'Approved',
  sent: 'Sent',
  accepted: 'Accepted',
  declined: 'Declined',
  rescinded: 'Rescinded',
  expired: 'Expired',
  // applications
  active: 'Active',
  hired: 'Hired',
  rejected: 'Rejected',
  withdrawn: 'Withdrawn',
  // interviews and scorecards
  scheduled: 'Scheduled',
  cancelled: 'Cancelled',
  completed: 'Completed',
  submitted: 'Submitted',
  // jobs and postings
  published: 'Published',
  archived: 'Archived',
  closed: 'Closed',
  paused: 'Paused',
  open: 'Open',
  public: 'Public',
  internal: 'Internal employees',
  both: 'Public and internal',
  hidden: 'Hidden',
  full_time: 'Full-time',
  part_time: 'Part-time',
  contract: 'Contract',
  internship: 'Internship',
  temporary: 'Temporary',
  // people
  candidate: 'Candidate',
  prospect: 'Prospect',
  employee: 'Employee',
  alumni: 'Alumni',
  // team roles
  'hiring-manager': 'Hiring manager',
  hiring_manager: 'Hiring manager',
  recruiter: 'Recruiter',
  coordinator: 'Coordinator',
  interviewer: 'Interviewer',
  owner: 'Owner',
  admin: 'Admin',
  // sequences
  stopped: 'Stopped',
  replied: 'Replied',
  finished: 'Finished',
  // offer checklist
  not_started: 'Not started',
  in_progress: 'In progress',
  complete: 'Complete',
  waived: 'Waived',
  made: 'Verbal offer made',
  // scorecard ratings
  strong_yes: 'Strong yes',
  yes: 'Yes',
  no: 'No',
  strong_no: 'Strong no',
  mixed: 'Mixed',
  // sourcing signals
  past_applicant: 'Past applicant',
  past_applicant_other_job: 'Applied to another job before',
  past_applicant_same_job: 'Applied to this job before',
  similar_job_title: 'Similar job title',
  silver_medalist: 'Silver medalist',
  same_department: 'Same department',
  skills_match: 'Skills match',
  // interviews
  no_show: 'No show',
  requested: 'Requested',
  needs_attention: 'Needs attention',
  confirmed: 'Confirmed',
  done: 'Done',
  not_eligible: 'Not eligible',
  on_track: 'On track',
  // stage transitions (stage history)
  move: 'Moved',
  hire: 'Marked hired',
  reject: 'Rejected',
  withdraw: 'Withdrew',
  archive: 'Archived',
  reopen: 'Reopened',
  unarchive: 'Reopened',
  convert: 'Converted to an application',
  // why someone is skipped when enrolling in a sequence
  no_email: 'No email address',
  do_not_contact: 'Marked do not contact',
  opted_out: 'Opted out of email',
  active_enrollment: 'Already in an active sequence',
  company_dnc: 'Works at a do-not-contact company',
  cooldown: 'Contacted too recently',
  consent_blocked: 'No consent to contact',
  excluded: 'Unchecked in the review',
  // reply classification
  interested: 'Interested',
  not_interested: 'Not interested',
  question: 'Asked a question',
  unsubscribe: 'Asked to unsubscribe',
  out_of_office: 'Out of office',
  bounce: 'Bounced',
  other: 'Other',
  // approval steps
  skipped: 'Skipped',
  no_approver: 'no approver on the hiring team',
  step_when_false: 'not needed for this offer',
  fallback: 'routed to the fallback approver',
  // stage types
  apply: 'Application review',
  screen: 'Screen',
  review: 'Review',
  interview: 'Interview',
  offer: 'Offer',
}

/** "pending_approval" → "Waiting for approval"; unknown values become sentence case. */
export function label(value: string | null | undefined): string {
  if (!value) return '—'
  const known = KNOWN[value]
  if (known) return known
  const words = value.replace(/[_-]+/g, ' ').trim()
  return words.charAt(0).toUpperCase() + words.slice(1)
}

/** Chip tone for a status: ok / warn / bad / neutral. */
export function statusTone(value: string | null | undefined): string {
  switch (value) {
    case 'active':
    case 'approved':
    case 'accepted':
    case 'hired':
    case 'published':
    case 'complete':
    case 'completed':
    case 'submitted':
    case 'scheduled':
    case 'sent':
      return 'chip chip-ok'
    case 'pending_approval':
    case 'changes_requested':
    case 'in_progress':
    case 'draft':
    case 'paused':
      return 'chip chip-warn'
    case 'rejected':
    case 'declined':
    case 'rescinded':
    case 'withdrawn':
    case 'expired':
    case 'cancelled':
      return 'chip chip-bad'
    default:
      return 'chip'
  }
}

/** Workspace display time zone (matches the application page's interview times). */
export const DISPLAY_TIME_ZONE = 'America/New_York'

/** "Tue, Nov 10 · 3:00 PM EST" — rendered on the server, so the zone is explicit. */
export function whenLabel(iso: string | null | undefined): string {
  if (!iso) return ''
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  const day = date.toLocaleDateString('en-US', {
    timeZone: DISPLAY_TIME_ZONE,
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })
  const time = date.toLocaleTimeString('en-US', {
    timeZone: DISPLAY_TIME_ZONE,
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short',
  })
  return `${day} · ${time}`
}

/** "Hi {{ person.display_name }}" → "Hi [Display name]" for lists; the editor keeps the real merge fields. */
export function readableMergeFields(text: string): string {
  return text.replace(
    /\{\{\s*([\w.]+)\s*\}\}/g,
    (_, field: string) => `[${label(field.split('.').pop() ?? field)}]`,
  )
}
