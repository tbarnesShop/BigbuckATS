/** Browser-only draft data: never credentials, results, inspected records or permission evidence. */
export type DraftScope = {
  organization: string
  persona: string
  sandbox: string
  generation: number
  surface: string
}
export type RawDraft = { fields: Record<string, string>; command: string; edited: boolean; recover: boolean }
type StorageLike = Pick<Storage, 'getItem' | 'setItem' | 'removeItem' | 'key' | 'length'>
const prefix = 'bigbuck:lab-draft:v1:'
const sensitive =
  /password|passwd|secret|token|authorization|credential|api[-_ ]?key|private[-_ ]?key|bearer\s|BEGIN .*PRIVATE|\b(?:ssn|salary|compensation)\b/i
export function memoryOnly(draft: RawDraft): boolean {
  return sensitive.test(JSON.stringify(draft.fields)) || sensitive.test(draft.command)
}
export function draftKey(scope: DraftScope, operation: string, schema: unknown): string {
  // Schema content is part of the identity, so a changed schema cannot revive old input.
  return (
    prefix +
    JSON.stringify([
      scope.organization,
      scope.sandbox,
      scope.generation,
      scope.persona,
      scope.surface,
      operation,
      schema,
    ])
  )
}
function valid(value: unknown): value is RawDraft {
  if (!value || typeof value !== 'object') return false
  const draft = value as RawDraft
  return (
    typeof draft.command === 'string' &&
    typeof draft.edited === 'boolean' &&
    typeof draft.recover === 'boolean' &&
    !!draft.fields &&
    typeof draft.fields === 'object' &&
    !Array.isArray(draft.fields) &&
    Object.values(draft.fields).every((v) => typeof v === 'string')
  )
}
export function clearStoredDrafts(storage: StorageLike | undefined) {
  try {
    if (!storage) return
    for (let i = storage.length - 1; i >= 0; i--) {
      const key = storage.key(i)
      if (key?.startsWith(prefix)) storage.removeItem(key)
    }
  } catch {
    /* Storage may be denied; drafts remain memory-only. */
  }
}
export class Drafts {
  private memory = new Map<string, RawDraft>()
  private persisted = new Set<string>()
  constructor(private storage?: StorageLike) {}
  read(key: string): RawDraft | undefined {
    const local = this.memory.get(key)
    if (local) return structuredClone(local)
    try {
      const raw = this.storage?.getItem(key)
      if (!raw) return
      const draft: unknown = JSON.parse(raw)
      if (!valid(draft) || !draft.recover || memoryOnly(draft)) {
        this.storage?.removeItem(key)
        return
      }
      this.memory.set(key, structuredClone(draft))
      this.persisted.add(key)
      return structuredClone(draft)
    } catch {
      return
    }
  }
  save(key: string, draft: RawDraft): boolean {
    this.memory.set(key, structuredClone(draft))
    this.persisted.delete(key)
    try {
      // Explicit sample-data consent is required in addition to the credential filter.
      if (!draft.recover || memoryOnly(draft)) this.storage?.removeItem(key)
      else if (this.storage) {
        this.storage.setItem(key, JSON.stringify(draft))
        this.persisted.add(key)
      }
    } catch {
      /* Quota/security failures must not lose the in-memory draft. */
    }
    return this.persisted.has(key)
  }
  unrecovered(): RawDraft[] {
    return [...this.memory]
      .filter(([key, value]) => value.edited && !this.persisted.has(key))
      .map(([, value]) => structuredClone(value))
  }
  discardUnrecovered() {
    for (const [key, value] of this.memory) {
      if (value.edited && !this.persisted.has(key)) {
        this.memory.delete(key)
        try {
          this.storage?.removeItem(key)
        } catch {
          /* denied storage */
        }
      }
    }
  }
  clear() {
    this.memory.clear()
    this.persisted.clear()
    clearStoredDrafts(this.storage)
  }
}
export function tabDraftStorage(): Storage | undefined {
  try {
    return typeof window === 'undefined' ? undefined : window.sessionStorage
  } catch {
    return
  }
}
