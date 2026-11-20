import { existsSync, readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

import type { AssetServer, ScriptEntry } from 'remix/assets'

/**
 * Browser assets come from one of two places:
 *
 * - Locally (dev, tests, Cloud Run): the Remix asset server compiles app and package modules per request.
 * - On Vercel: scripts/prebuild-assets.ts compiles every module at build time into app/assets-files.json
 *   (served below, cached at the edge) and writes app/assets-manifest.json with each client entry's script details. The function then
 *   never loads the asset compiler, whose native binaries and runtime-read package files Vercel's tracer
 *   cannot bundle.
 */
type AssetsManifest = {
  document: ScriptEntry
  entries: Record<string, ScriptEntry>
  pdfjsWorker: string
}

const webRoot = fileURLToPath(new URL('..', import.meta.url))
const manifestFile = fileURLToPath(new URL('./assets-manifest.json', import.meta.url))
const manifest: AssetsManifest | null = existsSync(manifestFile)
  ? (JSON.parse(readFileSync(manifestFile, 'utf8')) as AssetsManifest)
  : null

const nodeEnv = process.env.NODE_ENV ?? 'development'
const isDevelopment = nodeEnv === 'development'
const isHmr = Boolean(isDevelopment && process.env.REMIX_NODE_HMR)

async function createServer(): Promise<AssetServer> {
  const { createAssetServer } = await import('remix/assets')
  const { componentHmr } = await import('remix/component-hmr/assets')
  return createAssetServer({
    basePath: '/assets',
    allowFiles: ['app/routes.ts', 'app/**/public/**'],
    allowPackages: ['remix', 'pdfjs-dist'],
    denyFiles: ['app/**/*.test.*'],
    sourceMaps: isDevelopment ? 'external' : undefined,
    minify: !isDevelopment,
    watch: isDevelopment,
    hmr: isHmr
      ? {
          channel: async () => (await import('remix/node-hmr/runtime')).createBrowserHmrChannel(),
          moduleImporter: 'remix/multiple-import-maps-polyfill',
        }
      : undefined,
    scripts: { loaders: isHmr ? [componentHmr()] : undefined },
  })
}

/** The live asset server; null when serving the prebuilt manifest (Vercel). */
export const assets: AssetServer | null = manifest ? null : await createServer()

export const documentEntryFile = 'app/actions/public/entry.ts'

/** Manifest key for a module: its path under web/ without extension (compiled .mjs and source .tsx agree). */
export function entryKey(fileUrlOrPath: string): string {
  const path = fileUrlOrPath.startsWith('file:') ? fileURLToPath(fileUrlOrPath) : fileUrlOrPath
  const relative = path.startsWith(webRoot) ? path.slice(webRoot.length) : path
  return relative.replace(/\.(mjs|js|tsx|ts)$/, '')
}

/** What the renderer needs to turn clientEntry(import.meta.url) into script tags. */
export const renderAssets: Pick<AssetServer, 'getScriptEntry'> = {
  async getScriptEntry(entryId) {
    if (!manifest) return assets!.getScriptEntry(entryId)
    const entry = manifest.entries[entryKey(entryId)]
    if (!entry)
      throw new Error(`No prebuilt assets for ${entryKey(entryId)}; rerun scripts/prebuild-assets.ts`)
    return entry
  },
}

export const scriptEntry: ScriptEntry = manifest
  ? manifest.document
  : await assets!.getScriptEntry(documentEntryFile)

/**
 * pdf.js loads its worker, fonts and character maps by URL. Package URLs depend on where the asset server
 * finds the package, so ask it (or the manifest).
 */
const pdfjsWorker =
  manifest?.pdfjsWorker ??
  (await assets!.getHref(createRequire(import.meta.url).resolve('pdfjs-dist/build/pdf.worker.min.mjs')))
const pdfjsBase = pdfjsWorker.replace(/build\/[^/]+$/, '')
// Fonts and character maps are not file types the asset server serves; pdf.js falls back without them.
export const pdfjsUrls = {
  worker: pdfjsWorker,
  fonts: `${pdfjsBase}standard_fonts/`,
  cmaps: `${pdfjsBase}cmaps/`,
}

const ASSET_TYPES: Record<string, string> = {
  js: 'text/javascript; charset=utf-8',
  mjs: 'text/javascript; charset=utf-8',
  ts: 'text/javascript; charset=utf-8',
  tsx: 'text/javascript; charset=utf-8',
  css: 'text/css; charset=utf-8',
  json: 'application/json',
  map: 'application/json',
}

let files: Record<string, string> | null = null
const prebuiltFiles = () =>
  (files ??= JSON.parse(
    readFileSync(fileURLToPath(new URL('./assets-files.json', import.meta.url)), 'utf8'),
  ) as Record<string, string>)

/** Serves /assets/*: compiled live, or from the prebuilt files when the manifest is present. */
export async function serveAsset(request: Request): Promise<Response | null> {
  if (!manifest) return assets!.fetch(request)
  const pathname = decodeURIComponent(new URL(request.url).pathname)
  if (!pathname.startsWith('/assets/') || pathname.split('/').includes('..')) return null
  const body = prebuiltFiles()[pathname]
  if (!body) return null
  const type = ASSET_TYPES[pathname.split('.').pop() ?? ''] ?? 'application/octet-stream'
  return new Response(Buffer.from(body, 'base64'), {
    headers: {
      'Content-Type': type,
      // The edge keeps it for the life of this deployment (a new deploy starts a fresh cache); browsers
      // revalidate because URLs are not fingerprinted.
      'Cache-Control': 'public, max-age=0, must-revalidate, s-maxage=31536000',
    },
  })
}
