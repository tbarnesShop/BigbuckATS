import type { Handle } from 'remix/component'

import { FoldSectionTabs } from './app-nav.tsx'

export function SettingsNavigation(handle: Handle<{ orgQuery?: string }>) {
  return () => (
    <div class="settings-navigation">
      <FoldSectionTabs label="Settings sections" parent="settings" orgQuery={handle.props.orgQuery ?? ''} />
    </div>
  )
}
