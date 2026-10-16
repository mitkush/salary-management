import { describe, expect, it, vi } from 'vitest'
import { ApiError } from './api.js'
import { NETWORK_ERROR_MESSAGE, formErrorUpdate } from './formErrors.js'

describe('formErrorUpdate', () => {
  it('shows a network message when the server could not be reached, and logs the error', () => {
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})
    const error = new TypeError('Failed to fetch')

    expect(formErrorUpdate(error, ['terminated_on'])).toEqual({ fields: [], message: NETWORK_ERROR_MESSAGE })
    expect(log).toHaveBeenCalledWith(error)
    log.mockRestore()
  })

  it('puts API errors under the matching fields', () => {
    const error = new ApiError(422, { message: 'Invalid', details: { terminated_on: ["can't be blank"] } })

    expect(formErrorUpdate(error, ['terminated_on'])).toEqual({
      fields: [{ name: 'terminated_on', errors: ["can't be blank"] }],
      message: null,
    })
  })

  it('shows the API message when an error belongs to no field on the form', () => {
    const error = new ApiError(422, { message: 'Employee is invalid', details: { employee: ['is invalid'] } })

    expect(formErrorUpdate(error, ['terminated_on'])).toEqual({ fields: [], message: 'Employee is invalid' })
  })

  it('shows the API message when there are no field details', () => {
    const error = new ApiError(422, { message: 'Your session has expired. Please refresh the page.' })

    expect(formErrorUpdate(error, ['terminated_on'])).toEqual({
      fields: [],
      message: 'Your session has expired. Please refresh the page.',
    })
  })
})
