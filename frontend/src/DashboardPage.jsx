import { useEffect, useState } from 'react'
import { Alert, Button, Card, Col, Empty, Flex, Row, Segmented, Spin, Statistic, Typography } from 'antd'
import { Pie } from '@ant-design/charts'
import { useSearchParams } from 'react-router'
import { api } from './api.js'
import EmployeeFilters from './EmployeeFilters.jsx'
import { formatMoney } from './format.js'
import { applyFilterChanges, clearFilters, hasFilters } from './searchState.js'

const VIEWS = [
  { value: 'country', label: 'By country' },
  { value: 'department', label: 'By department' },
]

const STATS = [
  { key: 'headcount', title: 'Headcount', format: (value) => value.toLocaleString('en-US') },
  { key: 'total', title: 'Total salary cost', format: formatMoney },
  { key: 'average', title: 'Average salary', format: formatMoney },
  { key: 'median', title: 'Median salary', format: formatMoney },
  { key: 'min', title: 'Lowest salary', format: formatMoney },
  { key: 'max', title: 'Highest salary', format: formatMoney },
]

function DashboardPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [filterOptions, setFilterOptions] = useState({ countries: [], departments: [], job_titles: [] })
  const [optionsError, setOptionsError] = useState(null)
  const [result, setResult] = useState({ key: null, data: null, error: null })

  const query = Object.fromEntries(searchParams)
  const view = query.view === 'department' ? 'department' : 'country'
  const requestKey = `${searchParams.toString()}|${view}`
  const loading = result.key !== requestKey
  const error = optionsError ?? result.error

  useEffect(() => {
    api('/filter_options').then(setFilterOptions).catch((err) => setOptionsError(err.message))
  }, [])

  useEffect(() => {
    let ignore = false
    const params = Object.fromEntries(new URLSearchParams(requestKey.split('|')[0]))
    delete params.view
    api('/insights', { params: { ...params, group_by: view } })
      .then((data) => { if (!ignore) setResult({ key: requestKey, data, error: null }) })
      .catch((err) => { if (!ignore) setResult({ key: requestKey, data: null, error: err.message }) })
    return () => { ignore = true }
  }, [requestKey, view])

  function updateFilters(changes) {
    const next = applyFilterChanges(searchParams, changes)
    if (query.view) next.set('view', query.view)
    setSearchParams(next)
  }

  function changeView(value) {
    const next = new URLSearchParams(searchParams)
    next.set('view', value)
    setSearchParams(next)
  }

  const summary = result.data?.summary
  const groups = (result.data?.groups ?? []).map((group) => ({ ...group, total: Number(group.total), share: Number(group.share) }))

  return (
    <Flex vertical gap={16}>
      <Typography.Title level={3} style={{ margin: 0 }}>Dashboard</Typography.Title>
      <Typography.Text type="secondary">Active employees only. Salary means current annual gross (base + allowances), in USD.</Typography.Text>
      <Flex gap={8} wrap>
        <EmployeeFilters query={query} options={filterOptions} onChange={updateFilters} />
        {hasFilters(searchParams) && <Button onClick={() => setSearchParams(clearFilters(searchParams))}>Clear filters</Button>}
      </Flex>
      {error && <Alert type="error" message={error} showIcon />}
      <Spin spinning={loading && !error}>
        <Row gutter={[16, 16]}>
          {STATS.map((stat) => (
            <Col key={stat.key} xs={12} md={8} xl={4}>
              <Card size="small">
                <Statistic
                  title={stat.title}
                  value={summary?.[stat.key] ?? undefined}
                  formatter={(value) => (value === undefined || value === null ? '—' : stat.format(value))}
                />
              </Card>
            </Col>
          ))}
        </Row>
        <Card
          style={{ marginTop: 16 }}
          title="Salary cost breakdown"
          extra={<Segmented options={VIEWS} value={view} onChange={changeView} />}
        >
          {summary && summary.headcount === 0 ? (
            <Empty description="No active employees match these filters." />
          ) : (
            <Pie
              data={groups}
              angleField="total"
              colorField="name"
              innerRadius={0.6}
              height={360}
              label={false}
              legend={{ color: { position: 'right' } }}
              tooltip={{
                title: 'name',
                items: [
                  { field: 'total', name: 'Salary cost', valueFormatter: formatMoney },
                  { field: 'share', name: 'Share', valueFormatter: (value) => `${value}%` },
                ],
              }}
              annotations={[
                {
                  type: 'text',
                  style: {
                    text: summary ? `Total\n${formatMoney(summary.total)}` : '',
                    x: '50%',
                    y: '50%',
                    textAlign: 'center',
                    fontSize: 16,
                    fontWeight: 'bold',
                  },
                },
              ]}
            />
          )}
        </Card>
      </Spin>
    </Flex>
  )
}

export default DashboardPage
