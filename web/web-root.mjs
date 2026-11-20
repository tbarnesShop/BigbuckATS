// Records where web/ lives (this file's folder) for code that reads files beside it at runtime: docs, the
// asset server's sources and the lab's repo copy. On Vercel the working directory is not necessarily web/.
import { fileURLToPath } from 'node:url'

process.env.BIGBUCK_WEB_ROOT ??= fileURLToPath(new URL('.', import.meta.url)).replace(/\/$/, '')
