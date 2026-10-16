import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  applyFilterChanges,
  clearFilters,
  hasFilters,
  committedSearch,
  createSearchDebouncer,
  searchBoxText,
  typedSearch,
} from './searchState.js'

describe('applyFilterChanges', () => {
  it('keeps other filters and the page size, drops the page and empty values', () => {
    const params = new URLSearchParams('country_id=1&status=active&per_page=50&page=3')

    const next = applyFilterChanges(params, { q: 'smith', status: undefined })

    expect(Object.fromEntries(next)).toEqual({ country_id: '1', per_page: '50', q: 'smith' })
  })
})

describe('createSearchDebouncer', () => {
  let url
  let writes
  let debouncer

  beforeEach(() => {
    vi.useFakeTimers()
    url = new URLSearchParams('')
    writes = []
    debouncer = createSearchDebouncer({
      delay: 300,
      getParams: () => url,
      setParams: (next) => { writes.push(next.toString()); url = next },
    })
  })

  afterEach(() => vi.useRealTimers())

  it('writes only the last value after typing stops', () => {
    debouncer.type('s')
    debouncer.type('smith')
    vi.advanceTimersByTime(300)

    expect(writes).toEqual(['q=smith'])
  })

  it('keeps a filter picked while the search was waiting', () => {
    debouncer.type('smith')
    url = new URLSearchParams('country_id=1')
    vi.advanceTimersByTime(300)

    expect(writes).toEqual(['country_id=1&q=smith'])
  })

  it('drops the pending search when Back changed the search in the meantime', () => {
    url = new URLSearchParams('q=jo')
    debouncer.type('jones')
    url = new URLSearchParams('')
    vi.advanceTimersByTime(300)

    expect(writes).toEqual([])
  })

  it('calls onCommit with the value it wrote', () => {
    const committed = []
    debouncer = createSearchDebouncer({
      delay: 300,
      getParams: () => url,
      setParams: (next) => { url = next },
      onCommit: (value) => committed.push(value),
    })

    debouncer.type('smith')
    vi.advanceTimersByTime(300)

    expect(committed).toEqual(['smith'])
  })

  it('writes nothing after cancel', () => {
    debouncer.type('smith')
    debouncer.cancel()
    vi.advanceTimersByTime(300)

    expect(writes).toEqual([])
  })
})

describe('search box text', () => {
  it('shows what the user is typing', () => {
    expect(searchBoxText(typedSearch('smi', ''), '')).toBe('smi')
  })

  it('shows the URL search after Back clears it, not the old typed text', () => {
    const afterCommit = committedSearch('smith')

    expect(searchBoxText(afterCommit, 'smith')).toBe('smith')
    expect(searchBoxText(afterCommit, '')).toBe('')
  })

  it('shows the URL search when it was changed from outside', () => {
    expect(searchBoxText(typedSearch('smi', ''), 'jones')).toBe('jones')
  })
})

describe('clearing filters', () => {
  it('drops search, filters and page, but keeps the page size and the dashboard view', () => {
    const params = new URLSearchParams('q=smith&country_id=1&department=Finance&job_title=QA&status=active&page=3&per_page=50&view=department')

    expect(Object.fromEntries(clearFilters(params))).toEqual({ per_page: '50', view: 'department' })
  })

  it('knows whether any filter or search is set', () => {
    expect(hasFilters(new URLSearchParams('per_page=50&view=country&page=2'))).toBe(false)
    expect(hasFilters(new URLSearchParams('status=active'))).toBe(true)
  })
})

describe('the dashboard month', () => {
  it('is kept when a filter changes or filters are cleared', () => {
    const params = new URLSearchParams('as_of=2026-08&country_id=1')

    expect(applyFilterChanges(params, { department: 'Finance' }).get('as_of')).toBe('2026-08')
    expect(clearFilters(params).get('as_of')).toBe('2026-08')
    expect(hasFilters(new URLSearchParams('as_of=2026-08'))).toBe(false)
  })
})
