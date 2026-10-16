import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, download, setUnauthorizedHandler } from './api.js'

afterEach(() => {
  vi.unstubAllGlobals()
  setUnauthorizedHandler(() => {})
})

describe('download', () => {
  it('returns the file and the filename from Content-Disposition', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(new Blob([ 'xlsx-bytes' ]), {
      status: 200,
      headers: { 'Content-Disposition': 'attachment; filename="payroll-2026-10.xlsx"; filename*=UTF-8\'\'payroll-2026-10.xlsx' },
    })))

    const { blob, filename } = await download('/payroll_runs/2026-10/export')

    expect(filename).toBe('payroll-2026-10.xlsx')
    expect(await blob.text()).toBe('xlsx-bytes')
  })

  it('sends the user to login on 401 instead of returning the error as a file', async () => {
    const onUnauthorized = vi.fn()
    setUnauthorizedHandler(onUnauthorized)
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { message: 'Please log in.' } }), { status: 401 })))

    await expect(download('/payroll_runs/2026-10/export')).rejects.toBeInstanceOf(ApiError)
    expect(onUnauthorized).toHaveBeenCalled()
  })

  it('throws the API message on other errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { code: 'not_found', message: 'Not found.' } }), { status: 404 })))

    await expect(download('/payroll_runs/2026-05/export')).rejects.toMatchObject({ status: 404, message: 'Not found.' })
  })
})
