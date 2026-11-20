import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import type { CareersPage } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { Field, Mute, PrimaryButton, Shell } from '../../ui/shell.tsx'

export function CareersSettingsPage(
  handle: Handle<{
    careers: CareersPage
    orgQuery: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let { careers, orgQuery, notice, error } = handle.props
    return (
      <Shell
        title="Careers branding"
        eyebrow="Settings"
        orgQuery={orgQuery}
        backHref={routes.settingsIndex.href()}
        backLabel="Settings"
      >
        <Mute>
          Customize the careers page for {careers.organization.name} ({careers.organization.slug}).
        </Mute>
        {notice ? (
          <p mix={css({ color: 'var(--bb-accent)', fontWeight: 600, marginBottom: '16px' })}>{notice}</p>
        ) : null}
        {error ? (
          <p role="alert" mix={css({ color: 'var(--bb-danger)', marginBottom: '16px' })}>
            {error}
          </p>
        ) : null}
        <form
          method="post"
          action={`${routes.careersSettings.action.href()}${orgQuery}`}
          mix={css({ maxWidth: '32rem' })}
        >
          <Field
            label="Hero image URL"
            name="careers_hero_image_url"
            defaultValue={careers.careers.hero_image_url}
          />
          <Field label="Headline" name="careers_headline" defaultValue={careers.careers.headline} />
          <Field label="Subcopy" name="careers_subcopy" defaultValue={careers.careers.subcopy} />
          <PrimaryButton type="submit">Save branding</PrimaryButton>
        </form>
        <p mix={css({ marginTop: '28px' })}>
          <a
            href={`${routes.careersIndex.href()}?slug=${encodeURIComponent(careers.organization.slug)}`}
            mix={css({ color: 'var(--bb-accent)' })}
          >
            View public careers →
          </a>
        </p>
      </Shell>
    )
  }
}
