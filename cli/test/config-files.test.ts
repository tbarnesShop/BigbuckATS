import assert from 'node:assert/strict'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'

import { initConfigFolder, loadDocumentsFromDir, presetsDir } from '../src/config-files.ts'

test('presets exist and load as config documents', () => {
  assert.ok(presetsDir().endsWith('presets'))
  const dir = mkdtempSync(join(tmpdir(), 'bb-cfg-'))
  try {
    initConfigFolder(dir, 'recruiting-team', 'org-demo')
    const docs = loadDocumentsFromDir(dir)
    assert.ok(docs.length >= 2)
    assert.ok(docs.some((d) => d.kind === 'PipelineTemplate' && d.key === 'engineering-hiring'))
    assert.ok(docs.some((d) => d.kind === 'ReasonSet' && d.key === 'rejection'))
    assert.ok(docs.every((d) => d.spec && typeof d.spec === 'object'))
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})
