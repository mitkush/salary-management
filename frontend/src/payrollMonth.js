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
