const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
  'November', 'December']

export function toMonthParam(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}

export function monthLabel(param) {
  const [year, month] = param.split('-').map(Number)
  return `${MONTH_NAMES[month - 1]} ${year}`
}

export function findRun(runs, month) {
  return runs.find((run) => run.month === month)
}

export function missingRunMessage(param) {
  return /^\d{4}-(0[1-9]|1[0-2])$/.test(param) ? `No payroll for ${monthLabel(param)}.` : 'No payroll for this month.'
}

export function recentMonths(today, count) {
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(today.getFullYear(), today.getMonth() - index, 1)
    return { value: toMonthParam(date), label: `${MONTH_NAMES[date.getMonth()].slice(0, 3)} ${date.getFullYear()}` }
  })
}

export function previousMonth(today) {
  return toMonthParam(new Date(today.getFullYear(), today.getMonth() - 1, 1))
}
