import { useEffect, useState } from 'react'
import { Alert, Button, Flex, Table, Typography, message } from 'antd'
import { api } from './api.js'
import TaxRateModal from './TaxRateModal.jsx'

function CountriesPage() {
  const [reloadCount, setReloadCount] = useState(0)
  const [result, setResult] = useState({ key: null, data: [], error: null })
  const [editing, setEditing] = useState(null)
  const [messageApi, messageHolder] = message.useMessage()

  const loading = result.key !== reloadCount

  useEffect(() => {
    let ignore = false
    api('/countries')
      .then((data) => { if (!ignore) setResult({ key: reloadCount, data, error: null }) })
      .catch((err) => { if (!ignore) setResult((previous) => ({ ...previous, key: reloadCount, error: err.message })) })
    return () => { ignore = true }
  }, [reloadCount])

  function handleSaved(country) {
    setEditing(null)
    messageApi.success(`Tax rate for ${country.name} updated to ${Number(country.tax_rate_percent).toFixed(2)}%.`)
    setReloadCount((count) => count + 1)
  }

  const columns = [
    { title: 'Code', dataIndex: 'code', width: 100 },
    { title: 'Name', dataIndex: 'name' },
    {
      title: 'Tax rate',
      dataIndex: 'tax_rate_percent',
      align: 'right',
      render: (percent) => `${Number(percent).toFixed(2)} %`,
    },
    {
      title: '',
      key: 'actions',
      width: 100,
      render: (_, country) => <Button size="small" onClick={() => setEditing(country)}>Edit</Button>,
    },
  ]

  return (
    <Flex vertical gap={16}>
      {messageHolder}
      <Typography.Title level={3} style={{ margin: 0 }}>Countries</Typography.Title>
      <Typography.Text type="secondary">One flat tax rate per country, used when payroll is generated.</Typography.Text>
      {result.error && <Alert type="error" message={result.error} showIcon />}
      <Table
        rowKey="id"
        columns={columns}
        dataSource={result.data}
        loading={loading}
        pagination={false}
        locale={{ emptyText: 'No countries yet.' }}
      />
      {editing && <TaxRateModal country={editing} onClose={() => setEditing(null)} onSaved={handleSaved} />}
    </Flex>
  )
}

export default CountriesPage
