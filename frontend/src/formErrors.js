import { ApiError } from './api.js'

export const NETWORK_ERROR_MESSAGE = "Couldn't reach the server. Check your connection and try again."

export function formErrorUpdate(error, fieldNames) {
  if (!(error instanceof ApiError)) return { fields: [], message: NETWORK_ERROR_MESSAGE }

  const all = error.fieldErrors()
  const fields = all.filter((field) => fieldNames.includes(field.name))
  return { fields, message: all.length === 0 || fields.length < all.length ? error.message : null }
}
