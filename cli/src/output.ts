export function printJson(value: unknown): void {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`)
}

export function printTable(rows: Record<string, unknown>[], columns: string[]): void {
  if (!rows.length) {
    process.stdout.write('(none)\n')
    return
  }
  const widths = columns.map((col) =>
    Math.max(col.length, ...rows.map((r) => String(r[col] ?? '').length)),
  )
  const line = (cells: string[]) =>
    cells.map((c, i) => c.padEnd(widths[i])).join('  ')
  process.stdout.write(`${line(columns)}\n`)
  process.stdout.write(`${line(widths.map((w) => '-'.repeat(w)))}\n`)
  for (const row of rows) {
    process.stdout.write(`${line(columns.map((c) => String(row[c] ?? '')))}\n`)
  }
}

export function die(message: string, code = 1): never {
  process.stderr.write(`${message}\n`)
  process.exit(code)
}
