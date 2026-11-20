import * as assert from 'remix/assert'
import { describe, it } from 'remix/test'

import { filterCommands, type Command } from './commands.ts'

const commands: Command[] = [
  { id: 'today', label: 'Today', hint: 'What needs you', href: '/today', group: 'Go', areas: ['today'] },
  { id: 'people', label: 'People', hint: 'Directory', href: '/people', group: 'Go', areas: ['people'] },
  { id: 'job', label: 'New job', hint: 'Open a requisition board', href: '/jobs/new', group: 'Create', areas: [] },
]

describe('command list', () => {
  it('filters one list by label, hint, and group', () => {
    assert.equal(filterCommands(commands, '').length, 3)
    assert.equal(filterCommands(commands, 'req').map((command) => command.id).join(','), 'job')
    assert.equal(filterCommands(commands, 'create').map((command) => command.id).join(','), 'job')
    assert.equal(filterCommands(commands, 'zzz').length, 0)
  })
})
