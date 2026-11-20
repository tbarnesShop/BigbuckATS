import { createController } from 'remix/router'

import { setTheme } from '../../data/auth.ts'
import { routes } from '../../routes.ts'

/** Saves Auto / Light / Dark in the session and returns to the page it came from. */
export default createController(routes.theme, {
  actions: {
    index() {
      return new Response(null, { status: 303, headers: { Location: routes.home.href() } })
    },
    async action(context) {
      const form = await context.request.formData()
      setTheme(String(form.get('theme') ?? 'system'))
      // Only same-site paths: never an open redirect.
      const requested = String(form.get('return_to') ?? '')
      const back = requested.startsWith('/') && !requested.startsWith('//') ? requested : routes.home.href()
      return new Response(null, { status: 303, headers: { Location: back } })
    },
  },
})
