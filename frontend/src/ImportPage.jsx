import { useState } from 'react'
import { Alert, Button, Card, Col, Flex, Row, Space, Statistic, Table, Tag, Typography, Upload } from 'antd'
import { api } from './api.js'
import { formErrorUpdate } from './formErrors.js'

const rowColumns = [
  { title: 'Row', dataIndex: 'row', width: 80 },
  { title: 'Employee code', dataIndex: 'employee_code', render: (code) => code ?? '—' },
  {
    title: 'Status',
    dataIndex: 'status',
    render: (status) => <Tag color={status === 'failed' ? 'red' : 'default'}>{status}</Tag>,
  },
  { title: 'Reasons', dataIndex: 'reasons', render: (reasons) => reasons.join('; ') },
]

function ImportPage() {
  const [file, setFile] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState(null)
  const [error, setError] = useState(null)

  async function handleUpload() {
    const form = new FormData()
    form.append('file', file)
    setUploading(true)
    setError(null)
    setResult(null)
    try {
      setResult(await api('/employee_imports', { method: 'POST', body: form }))
      setFile(null)
    } catch (err) {
      setError(formErrorUpdate(err, []).message)
    } finally {
      setUploading(false)
    }
  }

  return (
    <Flex vertical gap={16}>
      <Typography.Title level={3} style={{ margin: 0 }}>Import employees</Typography.Title>
      <Typography.Paragraph type="secondary" style={{ margin: 0 }}>
        Upload an .xlsx file (up to 5 MB) with one employee per row. Each new employee gets a first salary revision on
        their joining date. Existing employees are never changed: identical rows are skipped, so the same file can be
        uploaded again.
      </Typography.Paragraph>
      <Space wrap>
        <Button href="/api/employee_imports/template">Download template</Button>
        <Upload
          accept=".xlsx"
          maxCount={1}
          fileList={file ? [ file ] : []}
          beforeUpload={(chosen) => { setFile(chosen); return false }}
          onRemove={() => setFile(null)}
        >
          <Button>Choose file</Button>
        </Upload>
        <Button type="primary" onClick={handleUpload} disabled={!file} loading={uploading}>
          Upload
        </Button>
      </Space>
      {error && <Alert type="error" message={error} showIcon />}
      {result && (
        <>
          <Row gutter={16}>
            <Col xs={8} md={4}><Card size="small"><Statistic title="Created" value={result.created} /></Card></Col>
            <Col xs={8} md={4}><Card size="small"><Statistic title="Skipped" value={result.skipped} /></Card></Col>
            <Col xs={8} md={4}><Card size="small"><Statistic title="Failed" value={result.failed} /></Card></Col>
          </Row>
          {result.rows.length > 0 ? (
            <Table rowKey="row" columns={rowColumns} dataSource={result.rows} size="small" pagination={{ pageSize: 50 }} />
          ) : (
            <Alert type="success" message="All rows were imported." showIcon />
          )}
        </>
      )}
    </Flex>
  )
}

export default ImportPage
