import * as assert from 'remix/assert'
import { it } from 'remix/test'

import { listReturn, recordHref, recordQuery } from './record-return.ts'

it('record returns retain only local list destinations and known filters', () => {
  for (const value of [
    'https://other.test/people',
    '//other.test/people',
    '/\\other.test/people',
    '/settings',
    '/people/123',
    '/%70eople',
  ]) {
    assert.equal(listReturn(value), undefined)
  }
  assert.equal(
    listReturn('/people?q=Ava&lifecycle_stage=candidate&token=secret#erase'),
    '/people?q=Ava&lifecycle_stage=candidate',
  )
  assert.equal(
    listReturn('/applications?job_id=job-1&stage=applied&page=2'),
    '/applications?job_id=job-1&stage=applied&page=2',
  )
  const href = recordHref('/people/123', '?slug=lab', '/search?q=Ava&slug=lab')
  const url = new URL(href, 'https://bigbuck.invalid')
  assert.equal(url.searchParams.get('slug'), 'lab')
  assert.equal(url.searchParams.get('return_to'), '/search?q=Ava&slug=lab')
  assert.equal(recordQuery(new URL('https://bigbuck.invalid/people/123?return_to=https://other.test')), '')
})
