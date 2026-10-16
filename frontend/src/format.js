const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

export function formatMoney(value) {
  return value === null || value === undefined ? '—' : usd.format(Number(value))
}

export const STATUS_COLORS = { active: 'green', upcoming: 'blue', terminated: 'default' }
