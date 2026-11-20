import { createController } from 'remix/router'

import {
  cancelFollowUp,
  completeFollowUp,
  listFollowUps,
  sessionFromRequest,
  type FollowUpTask,
} from '../../data/api.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { TasksPage, type TaskView } from './page.tsx'

function asView(value: unknown): TaskView {
  return value === 'all' || value === 'done' ? value : 'mine'
}

const QUERIES: Record<TaskView, Record<string, string>> = {
  mine: { assignee: 'me' },
  all: {},
  done: { status: 'completed' },
}

function message(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

export default createController(routes.tasks, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const view = asView(context.url.searchParams.get('view'))
      let tasks: FollowUpTask[] = []
      let error: string | undefined
      try {
        tasks = (await listFollowUps(session, QUERIES[view])).data
      } catch (caught) {
        error = message(caught)
      }
      return context.render(
        <TasksPage tasks={tasks} view={view} orgQuery={orgQuery(context.url)} error={error} />,
      )
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const view = asView(form.get('view'))
      const id = String(form.get('id') ?? '')
      let notice: string | undefined
      let error: string | undefined
      try {
        if (form.get('intent') === 'cancel') {
          await cancelFollowUp(session, id)
          notice = 'Task cancelled.'
        } else {
          await completeFollowUp(session, id)
          notice = 'Task done.'
        }
      } catch (caught) {
        error = message(caught)
      }
      // The Today follow-ups list posts here too; send people back where they were working.
      if (form.get('return') === 'today' && !error)
        return new Response(null, {
          status: 303,
          headers: { Location: `${routes.today.href()}${orgQuery(context.url)}#follow-ups` },
        })
      let tasks: FollowUpTask[] = []
      try {
        tasks = (await listFollowUps(session, QUERIES[view])).data
      } catch {
        // The list failing after a successful write should not hide the write's notice.
      }
      return context.render(
        <TasksPage
          tasks={tasks}
          view={view}
          orgQuery={orgQuery(context.url)}
          notice={notice}
          error={error}
        />,
      )
    },
  },
})
