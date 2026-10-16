import { afterEach, describe, expect, it, vi } from 'vitest'
import { api } from './api.js'

function stubFetch(responses) {
  const fetch = vi.fn()
  responses.forEach((body) => fetch.mockResolvedValueOnce(new Response(JSON.stringify(body), { status: 200 })))
  vi.stubGlobal('fetch', fetch)
  return fetch
}

afterEach(() => vi.unstubAllGlobals())

describe('api', () => {
  it('sends JSON bodies as JSON', async () => {
    const fetch = stubFetch([ { ok: true } ])

    await api('/things', { method: 'POST', body: { name: 'x' } })

    const [, options] = fetch.mock.calls[0]
    expect(options.headers['Content-Type']).toBe('application/json')
    expect(options.body).toBe('{"name":"x"}')
  })

  it('sends FormData as-is, letting the browser set the multipart header, with the CSRF token', async () => {
    const fetch = stubFetch([ { csrf_token: 'token-1' }, { created: 1 } ])
    await api('/session')
    const form = new FormData()
    form.append('file', new Blob([ 'x' ]), 'employees.xlsx')

    await api('/employee_imports', { method: 'POST', body: form })

    const [, options] = fetch.mock.calls[1]
    expect(options.body).toBe(form)
    expect(options.headers['Content-Type']).toBeUndefined()
    expect(options.headers['X-CSRF-Token']).toBe('token-1')
  })
})
