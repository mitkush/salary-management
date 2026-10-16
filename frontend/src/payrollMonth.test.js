import { describe, expect, it } from 'vitest'
import { findRun, missingRunMessage, monthLabel, toMonthParam } from './payrollMonth.js'

describe('payroll month helpers', () => {
  it('turns a date into the API month parameter', () => {
    expect(toMonthParam(new Date(2026, 9, 31))).toBe('2026-10')
    expect(toMonthParam(new Date(2027, 0, 1))).toBe('2027-01')
  })

  it('labels a month parameter for people', () => {
    expect(monthLabel('2026-10')).toBe('October 2026')
  })

  it('finds the run for a month, or nothing when it has not been generated', () => {
    const runs = [ { month: '2026-10' }, { month: '2026-09' } ]

    expect(findRun(runs, '2026-09')).toEqual({ month: '2026-09' })
    expect(findRun(runs, '2026-11')).toBeUndefined()
  })

  it('explains when the month in the URL has no payroll run', () => {
    expect(missingRunMessage('2026-01')).toBe('No payroll for January 2026.')
    expect(missingRunMessage('abc')).toBe('No payroll for this month.')
  })
})
