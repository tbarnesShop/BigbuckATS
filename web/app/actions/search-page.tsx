import type { Handle } from 'remix/component'

import type { Command } from '../data/commands.ts'
import { recordHref } from '../data/record-return.ts'
import { routes } from '../routes.ts'
import { Mute, RowLink, RowList, Shell } from '../ui/shell.tsx'

export function SearchPage(
  handle: Handle<{
    query: string
    commands: Command[]
    people: Array<{ id: string; display_name: string }>
    jobs: Array<{ id: string; title: string }>
    peopleState?: 'ready' | 'failed' | 'omitted'
    jobsState?: 'ready' | 'failed' | 'omitted'
    orgQuery: string
  }>,
) {
  return () => {
    const {
      query,
      commands,
      people,
      jobs,
      orgQuery,
      peopleState = 'ready',
      jobsState = 'ready',
    } = handle.props
    const params = new URLSearchParams(orgQuery)
    if (query) params.set('q', query)
    const returnTo = `${routes.search.href()}${params.size ? `?${params}` : ''}`
    return (
      <Shell title="Search" eyebrow="Jump" orgQuery={orgQuery}>
        <div class="list-workspace record-workspace stack">
          <form
            class="list-filters"
            method="get"
            action={routes.search.href()}
            role="search"
            aria-label="Search records and commands"
          >
            {params.get('slug') ? <input type="hidden" name="slug" value={params.get('slug')!} /> : null}
            <label class="field list-query">
              <span>Search or jump</span>
              <input name="q" type="search" defaultValue={query} />
            </label>
            <button class="btn btn-primary" type="submit">
              Search
            </button>
          </form>
          {query.trim() ? (
            <>
              {peopleState !== 'omitted' ? (
                <section class="record-section" aria-label="People">
                  <h2>
                    People{' '}
                    <span class="section-count">
                      {peopleState === 'ready' ? `${people.length} shown` : ''}
                    </span>
                  </h2>
                  {peopleState === 'failed' ? (
                    <p class="notice-bad" role="status">
                      People search is unavailable. <a href={returnTo}>Retry search</a>.
                    </p>
                  ) : people.length ? (
                    <>
                      <RowList>
                        {people.map((person) => (
                          <RowLink
                            key={person.id}
                            href={recordHref(
                              routes.peopleShow.index.href({ personId: person.id }),
                              orgQuery,
                              returnTo,
                            )}
                            title={person.display_name}
                          />
                        ))}
                      </RowList>
                      <a
                        href={
                          recordHref(routes.peopleIndex.href(), orgQuery) +
                          `${orgQuery ? '&' : '?'}${new URLSearchParams({ q: query })}`
                        }
                      >
                        View people results
                      </a>
                    </>
                  ) : (
                    <Mute>No people match this search.</Mute>
                  )}
                </section>
              ) : null}
              {jobsState !== 'omitted' ? (
                <section class="record-section" aria-label="Jobs">
                  <h2>
                    Jobs{' '}
                    <span class="section-count">{jobsState === 'ready' ? `${jobs.length} shown` : ''}</span>
                  </h2>
                  {jobsState === 'failed' ? (
                    <p class="notice-bad" role="status">
                      Job search is unavailable. <a href={returnTo}>Retry search</a>.
                    </p>
                  ) : jobs.length ? (
                    <RowList>
                      {jobs.map((job) => (
                        <RowLink
                          key={job.id}
                          href={`${routes.jobsShow.index.href({ jobId: job.id })}${orgQuery}`}
                          title={job.title}
                        />
                      ))}
                    </RowList>
                  ) : (
                    <Mute>No jobs match this search.</Mute>
                  )}
                </section>
              ) : null}
            </>
          ) : null}
          <section class="record-section" aria-label="Commands">
            <h2>
              Commands <span class="section-count">{commands.length} shown</span>
            </h2>
            {commands.length ? (
              <RowList>
                {commands.map((command) => (
                  <RowLink
                    key={command.id}
                    href={command.href}
                    title={command.label}
                    meta={`${command.group} · ${command.hint}`}
                  />
                ))}
              </RowList>
            ) : (
              <Mute>No commands match.</Mute>
            )}
          </section>
        </div>
      </Shell>
    )
  }
}
