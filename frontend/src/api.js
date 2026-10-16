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

  if (!response.ok) {
    if (response.status === 401) onUnauthorized()
    throw new ApiError(response.status, data?.error)
  }
  return data
}
