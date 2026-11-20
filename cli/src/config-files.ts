import { readdirSync, readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse as parseYaml, stringify as stringifyYaml } from 'yaml'

import type { ConfigDocument } from '@bigbuck/sdk'

const here = dirname(fileURLToPath(import.meta.url))

export function presetsDir(): string {
  // src/ -> ../presets or dist/ -> ../presets
  return join(here, '..', 'presets')
}

export type BigbuckYaml = {
  apiVersion?: string
  organization?: string
  manage?: string[]
}

export function loadDocumentsFromDir(dir: string): ConfigDocument[] {
  const docs: ConfigDocument[] = []
  walkYaml(dir, (file, text) => {
    const parts = text.split(/^---$/m).map((p) => p.trim()).filter(Boolean)
    for (const part of parts) {
      const doc = parseYaml(part) as Record<string, unknown>
      if (!doc || typeof doc !== 'object') continue
      if (doc.kind === undefined && doc.apiVersion) continue // bigbuck.yaml
      const kind = String(doc.kind ?? '')
      const metadata = (doc.metadata ?? {}) as Record<string, unknown>
      const key = String(metadata.key ?? doc.key ?? '')
      const spec = (doc.spec ?? doc) as Record<string, unknown>
      if (!kind || !key) continue
      const { kind: _k, key: _key, metadata: _m, apiVersion: _a, ...rest } = spec
      const cleanSpec =
        doc.spec && typeof doc.spec === 'object'
          ? (doc.spec as Record<string, unknown>)
          : rest
      docs.push({ kind, key, spec: cleanSpec })
    }
  })
  return docs
}

function walkYaml(dir: string, visit: (file: string, text: string) => void): void {
  if (!existsSync(dir)) return
  for (const name of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, name.name)
    if (name.isDirectory()) {
      walkYaml(path, visit)
      continue
    }
    if (!name.name.endsWith('.yaml') && !name.name.endsWith('.yml')) continue
    if (name.name === 'bigbuck.yaml') continue
    visit(path, readFileSync(path, 'utf8'))
  }
}

export function initConfigFolder(targetDir: string, preset: string, org?: string): void {
  const src = join(presetsDir(), preset)
  if (!existsSync(src)) {
    throw new Error(`Unknown preset "${preset}". Available: recruiting-team, admins-only`)
  }
  mkdirSync(targetDir, { recursive: true })
  copyDir(src, targetDir)
  const bbPath = join(targetDir, 'bigbuck.yaml')
  const bb: BigbuckYaml = {
    apiVersion: 'bigbuck/v1',
    organization: org ?? 'REPLACE_ORG_ID',
    manage: ['PipelineTemplate', 'ReasonSet'],
  }
  writeFileSync(bbPath, stringifyYaml(bb))
}

function copyDir(from: string, to: string): void {
  mkdirSync(to, { recursive: true })
  for (const name of readdirSync(from, { withFileTypes: true })) {
    const src = join(from, name.name)
    const dest = join(to, name.name)
    if (name.isDirectory()) {
      copyDir(src, dest)
    } else {
      writeFileSync(dest, readFileSync(src))
    }
  }
}
