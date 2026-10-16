import { Select } from 'antd'

function EmployeeFilters({ query, options, onChange }) {
  return (
    <>
      <Select
        placeholder="Country"
        allowClear
        value={query.country_id ? Number(query.country_id) : undefined}
        options={options.countries.map((country) => ({ value: country.id, label: country.name }))}
        onChange={(value) => onChange({ country_id: value })}
        style={{ width: 180 }}
      />
      <Select
        placeholder="Department"
        allowClear
        value={query.department}
        options={options.departments.map((department) => ({ value: department, label: department }))}
        onChange={(value) => onChange({ department: value })}
        style={{ width: 180 }}
      />
      <Select
        placeholder="Job title"
        allowClear
        showSearch
        value={query.job_title}
        options={options.job_titles.map((title) => ({ value: title, label: title }))}
        onChange={(value) => onChange({ job_title: value })}
        style={{ width: 220 }}
      />
    </>
  )
}

export default EmployeeFilters
