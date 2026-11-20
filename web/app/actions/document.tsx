import type { Handle, RemixNode } from 'remix/component'
import { css, unsafeHTML } from 'remix/component'
import { ImportMap } from 'remix/component/server'

import { scriptEntry } from '../assets.ts'
import { themeChoice } from '../data/auth.ts'
import { labCss } from '../ui/lab-css.ts'
import { docsCss } from '../ui/docs-css.ts'
import { kitCss } from '../ui/kit.ts'
import { themeCss } from '../ui/tokens.ts'

export interface DocumentProps {
  children?: RemixNode
  head?: RemixNode
  title?: string
}

const DEFAULT_TITLE = readAppDisplayName('Web')

export function Document(handle: Handle<DocumentProps>) {
  return () => {
    let { children, head, title = DEFAULT_TITLE } = handle.props
    let { href, importMap, preloads } = scriptEntry
    let theme = themeChoice()

    return (
      <html lang="en" data-theme={theme === 'system' ? undefined : theme}>
        <head>
          <meta charSet="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="color-scheme" content="light dark" />
          <link rel="icon" type="image/png" sizes="32x32" href="/favicon.png" />
          <link rel="preconnect" href="https://fonts.googleapis.com" />
          <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
          <link
            rel="stylesheet"
            href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&display=swap"
          />
          <title>{title}</title>
          <style data-bigbuck-theme innerHTML={unsafeHTML(themeCss)} />
          <style data-bigbuck-kit innerHTML={unsafeHTML(kitCss)} />
          <style data-bigbuck-lab innerHTML={unsafeHTML(labCss)} />
          <style data-bigbuck-docs innerHTML={unsafeHTML(docsCss)} />
          {head}
          <ImportMap value={importMap} />
          {preloads.map((preloadHref) => (
            <link key={preloadHref} rel="modulepreload" href={preloadHref} />
          ))}
          <script type="module" src={href}></script>
        </head>
        <body mix={css({ margin: 0, background: 'var(--bb-bg)', color: 'var(--bb-text)' })}>{children}</body>
      </html>
    )
  }
}

function readAppDisplayName(value: string): string {
  return value.startsWith('%%') ? 'Remix App' : decodeURIComponent(value)
}
