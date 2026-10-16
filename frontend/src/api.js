let csrfToken = null
let onUnauthorized = () => {}

export class ApiError extends Error {
  constructor(status, error) {
    super(error?.message ?? 'Something went wrong. Please try again.')
    this.status = status
    this.code = error?.code
    this.details = error?.details ?? {}
  }

  fieldErrors() {
    return Object.entries(this.details).map(([name, errors]) => ({ name, errors }))
  }
}

export function setUnauthorizedHandler(handler) {
  onUnauthorized = handler
}

export async function api(path, { method = 'GET', body, params } = {}) {
  const isForm = body instanceof FormData
  const headers = { Accept: 'application/json' }
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json'
  if (method !== 'GET' && csrfToken) headers['X-CSRF-Token'] = csrfToken

  const query = params ? new URLSearchParams(
    Object.entries(params).filter(([, value]) => value !== undefined && value !== null && value !== ''),
  ).toString() : ''

  const response = await fetch(`/api${path}${query ? `?${query}` : ''}`, {
    method,
    headers,
    body: body === undefined || isForm ? body : JSON.stringify(body),
    credentials: 'same-origin',
  })
  const data = response.status === 204 ? null : await response.json().catch(() => null)

  if (data?.csrf_token) csrfToken = data.csrf_token

  if (!response.ok) throw failure(response.status, data)
  return data
}

export async function download(path) {
  const response = await fetch(`/api${path}`, { credentials: 'same-origin' })

  if (!response.ok) throw failure(response.status, await response.json().catch(() => null))

  const disposition = response.headers.get('Content-Disposition') ?? ''
  const filename = disposition.match(/filename="([^"]+)"/)?.[1] ?? 'download'
  return { blob: await response.blob(), filename }
}

function failure(status, data) {
  if (status === 401) onUnauthorized()
  return new ApiError(status, data?.error)
}
