const KEPT_ON_FILTER_CHANGE = ['q', 'country_id', 'department', 'job_title', 'status', 'per_page']

export function applyFilterChanges(params, changes) {
  const next = { ...Object.fromEntries(params), ...changes }
  return new URLSearchParams(
    Object.entries(next).filter(([key, value]) => KEPT_ON_FILTER_CHANGE.includes(key) && value),
  )
}

export function createSearchDebouncer({ delay, getParams, setParams, onCommit = () => {} }) {
  let timer = null

  return {
    type(value) {
      clearTimeout(timer)
      const qWhenTyped = getParams().get('q') ?? ''
      timer = setTimeout(() => {
        const current = getParams()
        if ((current.get('q') ?? '') !== qWhenTyped) return
        setParams(applyFilterChanges(current, { q: value }))
        onCommit(value)
      }, delay)
    },
    cancel() {
      clearTimeout(timer)
    },
  }
}

export function typedSearch(value, urlQ) {
  return { text: value, forQ: urlQ }
}

export function committedSearch(value) {
  return { text: value, forQ: value }
}

export function searchBoxText(search, urlQ) {
  return search.forQ === urlQ ? search.text : urlQ
}
