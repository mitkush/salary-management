import { useEffect, useState } from 'react'
import { Alert, Button, Card, Col, Empty, Flex, Row, Segmented, Select, Spin, Statistic, Tooltip, Typography } from 'antd'
import { Column, Line, Pie } from '@ant-design/charts'
import { useSearchParams } from 'react-router'
import { api } from './api.js'
import EmployeeFilters from './EmployeeFilters.jsx'
import { formatMoney } from './format.js'
import { applyFilterChanges, clearFilters, hasFilters } from './searchState.js'
import { monthLabel, previousMonth, recentMonths } from './payrollMonth.js'

const VIEWS = [
  { value: 'country', label: 'By country' },
  { value: 'department', label: 'By department' },
]

const STATS = [
  {
    key: 'headcount',
    title: (
      <Tooltip title="Active at month end. Payroll also includes leavers who worked part of the month.">
        <span style={{ borderBottom: '1px dotted' }}>Headcount</span>
      </Tooltip>
    ),
    format: (value) => value.toLocaleString('en-US'),
  },
  { key: 'total', title: 'Annual salary cost', format: formatMoney },
  { key: 'monthly_cost', title: 'Monthly salary cost', format: formatMoney },
  { key: 'average', title: 'Average salary', format: formatMoney },
  { key: 'median', title: 'Median salary', format: formatMoney },
  { key: 'min', title: 'Lowest salary', format: formatMoney },
  { key: 'max', title: 'Highest salary', format: formatMoney },
]

function DashboardPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [today] = useState(() => new Date())
  const [filterOptions, setFilterOptions] = useState({ countries: [], departments: [], job_titles: [] })
  const [optionsError, setOptionsError] = useState(null)
  const [result, setResult] = useState({ key: null, data: null, error: null })
  const [trends, setTrends] = useState({ key: null, data: null, error: null })

  const query = Object.fromEntries(searchParams)
  const view = query.view === 'department' ? 'department' : 'country'
  const requestKey = `${searchParams.toString()}|${view}`
  const loading = result.key !== requestKey
  const trendsKey = new URLSearchParams([...searchParams].filter(([key]) => key !== 'view')).toString()
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

  useEffect(() => {
    let ignore = false
    api('/insights/trends', { params: Object.fromEntries(new URLSearchParams(trendsKey)) })
      .then((data) => { if (!ignore) setTrends({ key: trendsKey, data, error: null }) })
      .catch((err) => { if (!ignore) setTrends({ key: trendsKey, data: null, error: err.message }) })
    return () => { ignore = true }
  }, [trendsKey])

  function changeMonth(value) {
    const next = new URLSearchParams(searchParams)
    next.set('as_of', value)
    setSearchParams(next)
  }

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

  const trendMonths = trends.data?.months ?? []
  const summary = result.data?.summary
  const groups = (result.data?.groups ?? []).map((group) => ({ ...group, total: Number(group.total), share: Number(group.share) }))

  return (
    <Flex vertical gap={16}>
      <Typography.Title level={3} style={{ margin: 0 }}>Dashboard</Typography.Title>
      <Typography.Text type="secondary">Active employees at the chosen month's end. Salary is annual gross in USD.</Typography.Text>
      <Flex gap={8} wrap align="center">
        <Select
          value={query.as_of ?? previousMonth(today)}
          options={recentMonths(today, 24)}
          onChange={changeMonth}
          style={{ width: 130 }}
        />
        {result.data?.as_of && <Typography.Text type="secondary">As of {result.data.as_of}</Typography.Text>}
        <EmployeeFilters query={query} options={filterOptions} onChange={updateFilters} />
        {hasFilters(searchParams) && <Button onClick={() => setSearchParams(clearFilters(searchParams))}>Clear filters</Button>}
      </Flex>
      {error && <Alert type="error" message={error} showIcon />}
      <Spin spinning={loading && !error}>
        <Row gutter={[16, 16]}>
          {STATS.map((stat) => (
            <Col key={stat.key} xs={12} md={8} lg={6} xxl={3}>
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
      </Spin>
      {trends.error && <Alert type="error" message={trends.error} showIcon />}
      <Row gutter={[16, 16]}>
        <Col xs={24} lg={12}>
          <Spin spinning={loading && !error}>
          <Card
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
                height={300}
                label={{ text: (slice) => `${slice.share}%`, position: 'outside' }}
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
        </Col>
        <Col xs={24} lg={12}>
          <Spin spinning={trends.key !== trendsKey && !trends.error}>
            <Card title="Monthly salary cost, last 12 months">
              <Column
                data={trendMonths.map((m) => ({ month: monthLabel(m.month), cost: Number(m.monthly_cost) }))}
                xField="month"
                yField="cost"
                height={300}
                axis={{ y: { labelFormatter: (value) => formatMoney(value) } }}
                tooltip={{ items: [{ field: 'cost', name: 'Salary cost', valueFormatter: formatMoney }] }}
              />
            </Card>
          </Spin>
        </Col>
      </Row>
      <Spin spinning={trends.key !== trendsKey && !trends.error}>
        <Card title="Joiners and leavers, last 12 months">
          <Line
            data={trendMonths.flatMap((m) => [
              { month: monthLabel(m.month), type: 'Joiners', count: m.joiners },
              { month: monthLabel(m.month), type: 'Leavers', count: m.leavers },
            ])}
            xField="month"
            yField="count"
            colorField="type"
            height={300}
            point={{ shapeField: 'circle', sizeField: 3 }}
          />
        </Card>
      </Spin>
    </Flex>
  )
}

export default DashboardPage
