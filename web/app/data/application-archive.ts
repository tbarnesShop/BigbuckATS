/** Archive closes a job application using the existing audited outcome commands. */
export const archiveReasons = [
  { key: 'not_a_fit', label: 'Not a fit', command: 'reject' },
  { key: 'experience', label: 'Experience does not match', command: 'reject' },
  { key: 'role_filled', label: 'Role filled', command: 'reject' },
  { key: 'withdrew', label: 'Candidate withdrew', command: 'withdraw' },
  { key: 'another_offer', label: 'Accepted another offer', command: 'withdraw' },
] as const

export function applicationArchiveReason(value: string) {
  const reason = archiveReasons.find((reason) => reason.key === value)
  if (!reason) throw new Error('Choose a reason to archive this application.')
  return reason
}
