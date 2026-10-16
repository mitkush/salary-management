import { useEffect, useRef, useState } from 'react'
import { Alert, Flex, Input, Select, Table, Tag, Typography } from 'antd'
import { Link, useSearchParams } from 'react-router'
import { api } from './api.js'
import { STATUS_COLORS, formatMoney } from './format.js'

const STATUS_OPTIONS = ['active', 'upcoming', 'terminated'].map((status) => ({ value: status, label: status }))
const KEPT_ON_FILTER_CHANGE = ['q', 'country_id', 'department', 'job_title', 'status', 'per_page']

const columns = [
  {
    title: 'Code',
    dataIndex: 'employee_code',
    render: (code, employee) => <Link to={`/employees/${employee.id}`}>{code}</Link>,
  },
  { title: 'Name', dataIndex: 'full_name' },
  { title: 'Country', dataIndex: ['country', 'name'] },
  { title: 'Department', dataIndex: 'department' },
  { title: 'Job title', dataIndex: 'job_title' },
  { title: 'Status', dataIndex: 'status', render: (status) => <Tag color={STATUS_COLORS[status]}>{status}</Tag> },
  { title: 'Bank account', dataIndex: 'bank_account' },
  { title: 'Annual gross', dataIndex: 'current_annual_gross', align: 'right', render: formatMoney },
]

function EmployeesPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [filterOptions, setFilterOptions] = useState({ countries: [], departments: [], job_titles: [] })
  const [result, setResult] = useState({ key: null, data: [], meta: { page: 1, per_page: 25, total: 0 }, error: null })
  const [optionsError, setOptionsError] = useState(null)
  const urlQ = searchParams.get('q') ?? ''
  const [search, setSearch] = useState({ text: urlQ, forQ: urlQ })
  const searchText = search.forQ === urlQ ? search.text : urlQ
  const searchTimer = useRef(null)

  const query = Object.fromEntries(searchParams)
  const queryKey = searchParams.toString()

  const loading = result.key !== queryKey
  const error = optionsError ?? result.error

  useEffect(() => {
    api('/filter_options').then(setFilterOptions).catch((err) => setOptionsError(err.message))
  }, [])

  useEffect(() => {
    let ignore = false
    api('/employees', { params: Object.fromEntries(new URLSearchParams(queryKey)) })
      .then((data) => { if (!ignore) setResult({ ...data, key: queryKey, error: null }) })
      .catch((err) => { if (!ignore) setResult((previous) => ({ ...previous, key: queryKey, error: err.message })) })
    return () => { ignore = true }
  }, [queryKey])

  useEffect(() => () => clearTimeout(searchTimer.current), [])

  function updateFilters(changes) {
    setSearchParams((params) => {
      const next = { ...Object.fromEntries(params), ...changes }
      return Object.fromEntries(Object.entries(next).filter(([key, value]) => KEPT_ON_FILTER_CHANGE.includes(key) && value))
    })
  }

  function handleSearchChange(value) {
    setSearch({ text: value, forQ: urlQ })
    clearTimeout(searchTimer.current)
    searchTimer.current = setTimeout(() => updateFilters({ q: value }), 300)
  }

  function changePage(page, perPage) {
    setSearchParams({ ...query, page: String(page), per_page: String(perPage) })
  }

  return (
    <Flex vertical gap={16}>
      <Typography.Title level={3} style={{ margin: 0 }}>Employees</Typography.Title>
      <Flex gap={8} wrap>
        <Input.Search
          placeholder="Search name or code"
          allowClear
          value={searchText}
          onChange={(event) => handleSearchChange(event.target.value)}
          style={{ width: 240 }}
        />
        <Select
          placeholder="Country"
          allowClear
          value={query.country_id ? Number(query.country_id) : undefined}
          options={filterOptions.countries.map((country) => ({ value: country.id, label: country.name }))}
          onChange={(value) => updateFilters({ country_id: value })}
          style={{ width: 180 }}
        />
        <Select
          placeholder="Department"
          allowClear
          value={query.department}
          options={filterOptions.departments.map((department) => ({ value: department, label: department }))}
          onChange={(value) => updateFilters({ department: value })}
          style={{ width: 180 }}
        />
        <Select
          placeholder="Job title"
          allowClear
          showSearch
          value={query.job_title}
          options={filterOptions.job_titles.map((title) => ({ value: title, label: title }))}
          onChange={(value) => updateFilters({ job_title: value })}
          style={{ width: 220 }}
        />
        <Select
          placeholder="Status"
          allowClear
          value={query.status}
          options={STATUS_OPTIONS}
          onChange={(value) => updateFilters({ status: value })}
          style={{ width: 140 }}
        />
      </Flex>
      {error && <Alert type="error" message={error} showIcon />}
      <Table
        rowKey="id"
        columns={columns}
        dataSource={result.data}
        loading={loading}
        locale={{ emptyText: 'No employees match these filters.' }}
        pagination={{
          current: result.meta.page,
          pageSize: result.meta.per_page,
          total: result.meta.total,
          showSizeChanger: true,
          pageSizeOptions: [25, 50, 100],
          showTotal: (total) => `${total} employees`,
          onChange: changePage,
        }}
        scroll={{ x: true }}
      />
    </Flex>
  )
}

export default EmployeesPage
