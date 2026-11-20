import { listPersonDocuments, type ApiHeaders, type PersonDocument } from './api.ts'
import { signedIn } from './auth.ts'

export type PersonDocuments = { status: 'ready'; data: PersonDocument[] } | { status: 'failed' | 'omitted' }

export async function loadPersonDocuments(session: ApiHeaders, personId: string): Promise<PersonDocuments> {
  if (!signedIn()?.permissions?.includes('document.read')) return { status: 'omitted' }
  try {
    return { status: 'ready', data: (await listPersonDocuments(session, personId)).data }
  } catch {
    return { status: 'failed' }
  }
}
