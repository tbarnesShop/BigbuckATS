// Vercel build step (scripts/vercel-build.sh). Compiles every browser module with the Remix asset server
// once, packs them into app/assets-files.json (served by the function, cached at the edge), and records each client entry's script details in
// app/assets-manifest.json, which app/assets.ts serves from at runtime instead of compiling.
// Run from web/ with NODE_ENV=production. Both outputs are gitignored; delete them to go back to live
// compilation locally.
import { readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

const webRoot = process.cwd()
const manifestFile = join(webRoot, 'app/assets-manifest.json')
// One JSON file beside the manifest: Vercel's tracer bundles a file read by a fixed path, not a folder.
const filesFile = join(webRoot, 'app/assets-files.json')
const files: Record<string, string> = {}
rmSync(manifestFile, { force: true })
rmSync(filesFile, { force: true })

const { assets, entryKey, documentEntryFile } = await import('../app/assets.ts')
if (!assets) throw new Error('expected the live asset server while prebuilding')

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) return sourceFiles(path)
    return /\.(ts|tsx)$/.test(name) && !/\.test\./.test(name) ? [path] : []
  })
}

// Every browser module (they live under public/) that declares a clientEntry, keyed the way app/assets.ts looks them up.
const clientModules = sourceFiles(join(webRoot, 'app')).filter(
  (file) => file.includes('/public/') && /clientEntry\(\s*import\.meta\.url/.test(readFileSync(file, 'utf8')),
)
const entries: Record<string, Awaited<ReturnType<typeof assets.getScriptEntry>>> = {}
for (const file of clientModules) {
  entries[entryKey(file)] = await assets.getScriptEntry(pathToFileURL(file).href)
}
const document = await assets.getScriptEntry(documentEntryFile)
const { createRequire } = await import('node:module')
const pdfjsWorker = await assets.getHref(
  createRequire(import.meta.url).resolve('pdfjs-dist/build/pdf.worker.min.mjs'),
)

// Crawl from every entry, preload and import-map target, following /assets/ references in compiled code
// (dynamic imports such as pdf.js are not in the preload lists).
const queue = new Set<string>([pdfjsWorker])
for (const entry of [document, ...Object.values(entries)]) {
  queue.add(entry.href)
  for (const url of entry.preloads) queue.add(url)
  for (const url of Object.values(entry.importMap.imports ?? {})) queue.add(url)
  for (const scope of Object.values(entry.importMap.scopes ?? {}))
    for (const url of Object.values(scope)) queue.add(url)
}
const done = new Set<string>()
for (const url of queue) {
  // Only file URLs (route patterns like /assets/*path appear in the compiled routes module).
  if (done.has(url) || !/^\/assets\/[^*:]+\.[a-z0-9]+$/i.test(url)) continue
  done.add(url)
  const response = await assets.fetch(new Request(`http://prebuild.local${url}`))
  if (!response || !response.ok) throw new Error(`prebuild: ${url} -> ${response?.status ?? 'unhandled'}`)
  const body = Buffer.from(await response.arrayBuffer())
  files[decodeURIComponent(new URL(url, 'http://prebuild.local').pathname)] = body.toString('base64')
  if (/javascript/.test(response.headers.get('content-type') ?? '')) {
    for (const match of body.toString('utf8').matchAll(/["'`](\/assets\/[^"'`\s]+)["'`]/g))
      queue.add(match[1]!)
    // Relative imports inside compiled modules resolve against the module's own URL.
    for (const match of body.toString('utf8').matchAll(/(?:from|import\()\s*["'](\.\.?\/[^"']+)["']/g)) {
      queue.add(new URL(match[1]!, new URL(url, 'http://prebuild.local')).pathname)
    }
  }
}

writeFileSync(manifestFile, JSON.stringify({ document, entries, pdfjsWorker }, null, 2))
writeFileSync(filesFile, JSON.stringify(files))
console.log(
  `prebuilt ${done.size} asset files for ${clientModules.length} client entries -> app/assets-files.json`,
)
if (!files[decodeURIComponent(document.href)]) throw new Error('document entry missing')
