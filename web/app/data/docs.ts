import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { Marked, Renderer } from 'marked'
import { apiCatalog, cliHelp, repoRoot } from './lab/catalog.ts'
import { CURATED_TOOLS } from '../../../sdk/src/curated-graphql.ts'

export const chapters = [
  { slug: 'start', title: 'Start here', group: 'Explore' },
  { slug: 'data-model', title: 'Data model', group: 'Concepts' },
  { slug: 'agents', title: 'Agents as principals', group: 'Concepts' },
  { slug: 'permissions', title: 'Permissions & constraints', group: 'Concepts' },
  { slug: 'audit', title: 'Audit & events', group: 'Concepts' },
  { slug: 'privacy', title: 'Privacy & compliance', group: 'Concepts' },
  { slug: 'interop', title: 'Interoperability', group: 'Build' },
  { slug: 'limitations', title: 'Reference & limitations', group: 'Build' },
]
export const escapeHtml = (value: string) =>
  value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;')
export const headingId = (text: string) =>
  text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
const markdown = new Marked({
  gfm: true,
  renderer: {
    html: ({ text }) => escapeHtml(text),
    heading: ({ text, depth }) => `<h${depth} id="${headingId(text)}">${text}</h${depth}>`,
    code: ({ text, lang }) =>
      `<div class="docs-code"><div class="docs-code-toolbar"><span>${escapeHtml(lang ?? 'Example')}</span><button type="button" data-copy-code>Copy</button></div><pre role="region" aria-label="${escapeHtml(lang ?? 'Example')} code example" tabindex="0"><code>${escapeHtml(text)}</code></pre></div>`,
    table(token) {
      return `<div class="docs-table" role="region" aria-label="Documentation table" tabindex="0">${Renderer.prototype.table.call(this, token)}</div>`
    },
  },
})
export function renderDocsMarkdown(source: string): string {
  return markdown.parse(source) as string
}
export function docsIndex() {
  return chapters.map((chapter) => {
    const source = readFileSync(new URL(`../../docs/${chapter.slug}.md`, import.meta.url), 'utf8')
    return { ...chapter, source, searchText: source.replace(/[`#*[\]]/g, '') }
  })
}
export function article(slug: string) {
  const page = docsIndex().find((p) => p.slug === slug)
  if (!page) return null
  return {
    ...page,
    html: renderDocsMarkdown(page.source),
    headings: [...page.source.matchAll(/^## (.+)$/gm)].map((m) => ({ title: m[1], id: headingId(m[1]) })),
  }
}
export function reference(
  kind: string,
): { title: string; html: string; headings: Array<{ title: string; id: string }> } | null {
  let title = '',
    source = ''
  if (kind === 'rest') {
    title = 'REST reference'
    source =
      '# REST reference\n\nGenerated from the committed OpenAPI contract. These are product operations; shared-demo restrictions still apply.\n\n'
    for (const op of apiCatalog())
      source += `## ${op.name}\n\n\`${op.method} ${op.path}\`\n\n${op.description}\n\n[Prepare in the lab →](/session?surface=api&operation=${op.name})\n\n\`\`\`json\n${JSON.stringify(op.bodySchema?.properties ? op.bodySchema : op.inputSchema, null, 2)}\n\`\`\`\n\n`
  } else if (kind === 'graphql') {
    title = 'GraphQL schema'
    // Prefer the web/docs copy (bundled via import.meta.url on Vercel). Fall back to the
    // monorepo root / .repo path for local runs that have not executed vercel-build.sh.
    let schema: string
    try {
      schema = readFileSync(new URL('../../docs/schema.graphql', import.meta.url), 'utf8')
    } catch {
      schema = readFileSync(resolve(repoRoot, 'schema.graphql'), 'utf8')
    }
    source =
      '# GraphQL schema\n\nThe committed schema served by the Rails implementation. Browser sessions use registered documents.\n\n```graphql\n' +
      schema +
      '\n```'
  } else if (kind === 'cli') {
    title = 'CLI reference'
    source =
      '# CLI reference\n\nExtracted from the CLI command help. The browser runner supplies credentials and only permits files inside its temporary directory.\n\n```text\n' +
      cliHelp() +
      '\n```\n\n[Try in the lab →](/session?surface=cli&prepare=1)'
  } else if (kind === 'mcp') {
    title = 'MCP reference'
    source =
      '# MCP reference\n\nGenerated REST tools and curated GraphQL tools. The lab discovers its executable catalog through MCP at runtime.\n\n'
    const generated = JSON.parse(readFileSync(resolve(repoRoot, 'mcp/generated/tools.json'), 'utf8')) as {
      tools: any[]
    }
    const curated = CURATED_TOOLS.map((tool) => ({
      ...tool,
      inputSchema: {
        type: 'object',
        properties: Object.fromEntries(
          Object.entries(tool.variables).map(([key, { required: _required, ...spec }]) => [key, spec]),
        ),
        required: Object.entries(tool.variables)
          .filter(([, spec]) => spec.required)
          .map(([key]) => key),
      },
      description: tool.description,
    }))
    for (const tool of [
      ...curated,
      {
        name: 'graphql_query',
        description: 'Execute a GraphQL document with optional variables.',
        inputSchema: {
          type: 'object',
          properties: { query: { type: 'string' }, variables: { type: 'object' } },
          required: ['query'],
        },
      },
      ...generated.tools,
    ])
      source += `## ${tool.name}\n\n${tool.description}\n\n[Prepare in the lab →](/session?surface=mcp&operation=${tool.name})\n\n\`\`\`json\n${JSON.stringify(tool.inputSchema, null, 2)}\n\`\`\`\n\n`
  } else return null
  return {
    title,
    html: renderDocsMarkdown(source),
    headings: [...source.matchAll(/^## (.+)$/gm)].map((m) => ({ title: m[1], id: headingId(m[1]) })),
  }
}
