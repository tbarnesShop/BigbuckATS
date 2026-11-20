import type { Handle } from 'remix/component'

import type { Affiliation, Company } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { EmptyState, Shell } from '../../ui/shell.tsx'

export function CompaniesIndexPage(handle: Handle<{ companies: Company[]; orgQuery: string }>) {
  return () => {
    let { companies, orgQuery } = handle.props
    return (
      <Shell title="Companies" eyebrow="People" orgQuery={orgQuery}>
        <FoldSectionTabs label="People sections" parent="people" orgQuery={orgQuery} />
        <p class="sub mute">{companies.length} companies shown.</p>
        {companies.length === 0 ? (
          <EmptyState>
            No companies yet. Record where someone works from their{' '}
            <a href={`${routes.peopleIndex.href()}${orgQuery}`}>person page</a>.
          </EmptyState>
        ) : (
          <div class="list-workspace">
            <div class="table-wrap" role="region" aria-label="Companies results" tabIndex={0}>
              <table class="table">
                <thead>
                  <tr>
                    <th>Company</th>
                    <th>Industry</th>
                    <th>Size</th>
                    <th>Current</th>
                    <th>Former</th>
                  </tr>
                </thead>
                <tbody>
                  {companies.map((company) => (
                    <tr key={company.id}>
                      <td>
                        <a href={`${routes.companiesShow.index.href({ companyId: company.id })}${orgQuery}`}>
                          {company.name}
                        </a>
                        {company.domain ? <div class="sub">{company.domain}</div> : null}
                      </td>
                      <td>{company.industry || '—'}</td>
                      <td>{company.employee_band || '—'}</td>
                      <td>{company.current_count ?? 0}</td>
                      <td>{company.former_count ?? 0}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Shell>
    )
  }
}

export function CompanyShowPage(
  handle: Handle<{ company: Company; affiliations: Affiliation[]; orgQuery: string }>,
) {
  return () => {
    let { company, affiliations, orgQuery } = handle.props
    return (
      <Shell
        title={company.name}
        eyebrow="Company"
        orgQuery={orgQuery}
        backHref={`${routes.companiesIndex.href()}${orgQuery}`}
        backLabel="Companies"
      >
        <div class="chip-row">
          {company.industry ? <span class="chip chip-info">{company.industry}</span> : null}
          {company.employee_band ? <span class="chip">{company.employee_band}</span> : null}
          <span class="chip chip-ok">{company.current_count ?? 0} current</span>
          <span class="chip">{company.former_count ?? 0} former</span>
        </div>
        {company.domain ? <p class="sub">{company.domain}</p> : null}
        {affiliations.length === 0 ? (
          <EmptyState>No one is linked to this company yet.</EmptyState>
        ) : (
          <div class="list-workspace">
            <div class="table-wrap" role="region" aria-label="Company affiliations" tabIndex={0}>
              <table class="table">
                <thead>
                  <tr>
                    <th>Person</th>
                    <th>Title</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {affiliations.map((row) => (
                    <tr key={row.id}>
                      <td>
                        <a href={`${routes.peopleShow.index.href({ personId: row.person_id })}${orgQuery}`}>
                          {row.person?.display_name ?? 'Person'}
                        </a>
                      </td>
                      <td>{row.title || '—'}</td>
                      <td>
                        <span class={row.current ? 'chip chip-ok' : 'chip'}>
                          {row.current ? 'Current' : 'Former'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Shell>
    )
  }
}
