import { routes } from '../routes.ts'
import { recordHref } from './record-return.ts'

export const personTabs = [
  { id: 'applications', label: 'Application history' },
  { id: 'details', label: 'Person details' },
  { id: 'resume', label: 'Resume' },
  { id: 'activity', label: 'Activity' },
] as const
export type PersonTab = (typeof personTabs)[number]['id']

export function personTab(value: string | null | undefined): PersonTab {
  return personTabs.some((tab) => tab.id === value) ? (value as PersonTab) : 'applications'
}

export function personWorkspaceHref(
  personId: string,
  orgQuery: string,
  returnTo: string | undefined,
  tab: PersonTab,
) {
  const href = recordHref(routes.peopleShow.index.href({ personId }), orgQuery, returnTo)
  return `${href}${href.includes('?') ? '&' : '?'}tab=${tab}`
}
