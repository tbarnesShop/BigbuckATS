import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto'
import { mkdirSync, readFileSync, readdirSync, unlinkSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// The browser session holds an opaque reference. Only the Node host reads these credentials.
type Credentials = { toolToken: string; agentToken: string; expiresAt: string }
const directory = () =>
  process.env.LAB_CREDENTIAL_DIR ?? fileURLToPath(new URL('../../../../tmp/lab-sessions/', import.meta.url))
const validKey = (key: string) => /^[a-f0-9]{48}$/.test(key)
let cleanedAt = 0

// On Vercel there is no lasting disk and several instances serve one site, so the "reference" is the
// credentials themselves, AES-256-GCM sealed with a key derived from SESSION_SECRET. It then rides in the
// session cookie, which is already encrypted and HTTP-only, and expires with the sandbox.
const SEALED = 'sealed.'
const sealedMode = () => process.env.LAB_CREDENTIAL_STORE === 'cookie'
const sealKey = () => {
  const secret = process.env.SESSION_SECRET
  if (!secret) throw new Error('SESSION_SECRET is required to seal lab credentials')
  return createHash('sha256').update(`bigbuck-lab-credentials:${secret}`).digest()
}

function seal(credentials: Credentials): string {
  const iv = randomBytes(12)
  const cipher = createCipheriv('aes-256-gcm', sealKey(), iv)
  const body = Buffer.concat([cipher.update(JSON.stringify(credentials), 'utf8'), cipher.final()])
  return SEALED + Buffer.concat([iv, cipher.getAuthTag(), body]).toString('base64url')
}

function unseal(value: string): Credentials | null {
  try {
    const raw = Buffer.from(value.slice(SEALED.length), 'base64url')
    const decipher = createDecipheriv('aes-256-gcm', sealKey(), raw.subarray(0, 12))
    decipher.setAuthTag(raw.subarray(12, 28))
    const data = JSON.parse(
      Buffer.concat([decipher.update(raw.subarray(28)), decipher.final()]).toString('utf8'),
    ) as Credentials
    if (!(Date.parse(data.expiresAt) > Date.now())) return null
    return typeof data.toolToken === 'string' && typeof data.agentToken === 'string' ? data : null
  } catch {
    return null
  }
}

export function readLabCredentials(key: string): Credentials | null {
  if (key.startsWith(SEALED)) return unseal(key)
  if (!validKey(key)) return null
  const path = resolve(directory(), `${key}.json`)
  try {
    const data = JSON.parse(readFileSync(path, 'utf8')) as Credentials
    if (Date.parse(data.expiresAt) <= Date.now() || !Number.isFinite(Date.parse(data.expiresAt))) {
      unlinkSync(path)
      return null
    }
    return typeof data.toolToken === 'string' && typeof data.agentToken === 'string' ? data : null
  } catch {
    return null
  }
}

export function storeLabCredentials(credentials: Credentials): string {
  if (sealedMode()) return seal(credentials)
  mkdirSync(directory(), { recursive: true, mode: 0o700 })
  if (Date.now() - cleanedAt > 60000) {
    for (const file of readdirSync(directory())) {
      if (/^[a-f0-9]{48}\.json$/.test(file)) readLabCredentials(file.slice(0, -5))
    }
    cleanedAt = Date.now()
  }
  const key = randomBytes(24).toString('hex')
  writeFileSync(resolve(directory(), `${key}.json`), JSON.stringify(credentials), { mode: 0o600, flag: 'wx' })
  return key
}
