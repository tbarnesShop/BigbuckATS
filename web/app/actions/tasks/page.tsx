import type { Handle } from 'remix/component'

import type { FollowUpTask } from '../../data/api.ts'
import { label, whenLabel } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FilterSegments } from '../../ui/page-chrome.tsx'
import { EmptyState, Shell } from '../../ui/shell.tsx'

export type TaskView = 'mine' | 'all' | 'done'

export const TASK_VIEWS: Array<[TaskView, string]> = [
  ['mine', 'Mine'],
  ['all', 'Everyone'],
  ['done', 'Done'],
]

export function TasksPage(
  handle: Handle<{
    tasks: FollowUpTask[]
    view: TaskView
    orgQuery?: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let { tasks, view, orgQuery = '', notice, error } = handle.props
    let action = `${routes.tasks.action.href()}${orgQuery}`
    return (
      <Shell title="Tasks" sub="Follow-ups for people you are working" orgQuery={orgQuery}>
        <FilterSegments
          label="Task views"
          links={TASK_VIEWS.map(([value, text]) => ({
            href: `${routes.tasks.index.href()}?view=${value}${orgQuery.replace('?', '&')}`,
            label: text,
            current: value === view,
          }))}
        />
        {notice ? (
          <p class="notice" role="status">
            {notice}
          </p>
        ) : null}
        {error ? (
          <p class="error" role="alert">
            {error}
          </p>
        ) : null}
        {tasks.length === 0 ? (
          <EmptyState>
            {view === 'done'
              ? 'Nothing completed yet.'
              : 'No open tasks. Sequence steps and the person page add them here.'}
          </EmptyState>
        ) : (
          <ul class="queue">
            {tasks.map((task) => (
              <li key={task.id} class="queue-item">
                <div class="body">
                  <span class="title">{task.title}</span>
                  <span class="hint">
                    {label(task.task_type)}
                    {task.person ? (
                      <>
                        {' · '}
                        <a href={`/people/${task.person.id}${orgQuery}`}>{task.person.display_name}</a>
                      </>
                    ) : null}
                    {task.due_at ? ` · Due ${whenLabel(task.due_at)}` : ''}
                    {task.overdue ? ' · Overdue' : ''}
                  </span>
                </div>
                {task.status === 'open' ? (
                  <form method="post" action={action} class="row-actions">
                    <input type="hidden" name="id" value={task.id} />
                    <input type="hidden" name="view" value={view} />
                    <button class="btn btn-primary btn-small" type="submit" name="intent" value="complete">
                      Done
                    </button>
                    <button class="btn btn-ghost btn-small" type="submit" name="intent" value="cancel">
                      Cancel
                    </button>
                  </form>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </Shell>
    )
  }
}
