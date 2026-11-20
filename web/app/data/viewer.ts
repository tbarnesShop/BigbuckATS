import { rememberPermissions } from './auth.ts'
import type { ApiHeaders } from './api.ts'
import { gql } from './graphql.ts'
import type { ViewerQuery } from '../graphql/generated.ts'

/** Loads who the session acts as and caches their permissions for the nav. */
export async function refreshViewer(ctx: ApiHeaders): Promise<ViewerQuery['viewer'] | null> {
  try {
    const { viewer } = await gql<ViewerQuery>(ctx, 'Viewer')
    rememberPermissions({ permissions: viewer.permissions, roleKey: viewer.roleKey })
    return viewer
  } catch {
    rememberPermissions(null)
    return null
  }
}
