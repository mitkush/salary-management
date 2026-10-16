import { describe, expect, it } from 'vitest'
import { dashboardQuery, findRun, missingRunMessage, monthLabel, monthOptions, previousMonth, recentMonths, toMonthParam } from './payrollMonth.js'

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

  it('lists recent months, newest first, labelled like "Sep 2026"', () => {
    const months = recentMonths(new Date(2026, 9, 16), 24)

    expect(months).toHaveLength(24)
    expect(months[0]).toEqual({ value: '2026-10', label: 'Oct 2026' })
    expect(months[1]).toEqual({ value: '2026-09', label: 'Sep 2026' })
    expect(months[23]).toEqual({ value: '2024-11', label: 'Nov 2024' })
  })

  it('gives the previous month as the default, across a year boundary too', () => {
    expect(previousMonth(new Date(2026, 9, 16))).toBe('2026-09')
    expect(previousMonth(new Date(2027, 0, 5))).toBe('2026-12')
  })

  it('adds a selected month from the URL that is older than the recent months', () => {
    const options = monthOptions(new Date(2026, 9, 16), '2023-12')

    expect(options).toHaveLength(25)
    expect(options.at(-1)).toEqual({ value: '2023-12', label: 'Dec 2023' })
    expect(monthOptions(new Date(2026, 9, 16), '2026-09')).toHaveLength(24)
  })

  it('always sends the month to the API, defaulting to last month, and leaves out the UI-only view', () => {
    const today = new Date(2026, 10, 1, 2)

    expect(dashboardQuery(new URLSearchParams('view=department&country_id=1'), today)).toEqual({ country_id: '1', as_of: '2026-10' })
    expect(dashboardQuery(new URLSearchParams('as_of=2025-03'), today)).toEqual({ as_of: '2025-03' })
  })
})
