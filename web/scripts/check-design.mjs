import { readdir, readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { join } from 'node:path'

const root = fileURLToPath(new URL('../app/', import.meta.url))
const legacy =
  /\bcolor\.(?:mist|birch|glass|ink|muted|rule(?:Soft|Strong)?|canopy(?:Tint)?|onCanopy|copper(?:Hover)?|onCopper|ok|warn)\b|\bfont\.brand\b|--font-serif\b|var\(--bb-(?:ink|muted|line(?:-soft|-strong)?|surface-glass|accent-tint|highlight(?:-hover)?|on-highlight|ok|warn)\)|font-family\s*:[^;\n]*(?:Georgia|Times New Roman|Cormorant|Fraunces)/i
let failures = []
async function scan(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) await scan(path)
    else if (/\.(?:ts|tsx)$/.test(entry.name) && !/\.test\.|generated\./.test(entry.name)) {
      const source = await readFile(path, 'utf8')
      source.split('\n').forEach((line, index) => {
        if (legacy.test(line)) failures.push(`${path}:${index + 1}: obsolete design alias or font`)
      })
    }
  }
}
await scan(root)
if (failures.length) {
  console.error(failures.join('\n'))
  process.exitCode = 1
} else console.log('Design drift check passed: semantic tokens and shared font roles.')
