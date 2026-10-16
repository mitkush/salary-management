import { useEffect, useState } from 'react'
import { Alert, Button, Descriptions, Flex, Result, Space, Spin, Table, Tag, Typography } from 'antd'
import { Link, useParams } from 'react-router'
import { api } from './api.js'
import AddRevisionModal from './AddRevisionModal.jsx'
import TerminateModal from './TerminateModal.jsx'
import { STATUS_COLORS, formatMoney } from './format.js'

const revisionColumns = [
  { title: 'Effective date', dataIndex: 'effective_on' },
  {
    title: 'Reason',
    dataIndex: 'reason',
    render: (reason, revision) => (
      <Space>
        {reason}
        {revision.never_applies && <Tag>Never applied</Tag>}
      </Space>
    ),
  },
  { title: 'Annual base', dataIndex: 'annual_base', align: 'right', render: formatMoney },
  { title: 'Allowances', dataIndex: 'annual_allowances', align: 'right', render: formatMoney },
  { title: 'Deductions', dataIndex: 'annual_deductions', align: 'right', render: formatMoney },
  { title: 'Annual gross', dataIndex: 'annual_gross', align: 'right', render: formatMoney },
]

function EmployeeDetailPage() {
  const { id } = useParams()
  const [reloadCount, setReloadCount] = useState(0)
  const [result, setResult] = useState({ key: null, data: null, error: null })
  const [openModal, setOpenModal] = useState(null)

  const requestKey = `${id}:${reloadCount}`
  const showingThisEmployee = result.key?.split(':')[0] === id
  const loading = !showingThisEmployee

  useEffect(() => {
    let ignore = false
    api(`/employees/${id}`)
      .then((data) => { if (!ignore) setResult({ key: requestKey, data, error: null }) })
      .catch((err) => { if (!ignore) setResult({ key: requestKey, data: null, error: err }) })
    return () => { ignore = true }
  }, [id, requestKey])

  function handleSaved() {
    setOpenModal(null)
    setReloadCount((count) => count + 1)
  }

  if (loading) {
    return <Flex justify="center" style={{ padding: 48 }}><Spin size="large" /></Flex>
  }

  if (result.error?.status === 404) {
    return (
      <Result
        status="404"
        title="Employee not found"
        extra={<Link to="/employees"><Button type="primary">Back to employees</Button></Link>}
      />
    )
  }

  if (result.error) return <Alert type="error" message={result.error.message} showIcon />

  const { employee, revisions } = result.data

  return (
    <Flex vertical gap={16}>
      <Link to="/employees">← Employees</Link>
      <Flex justify="space-between" align="center" wrap gap={8}>
        <Space align="center">
          <Typography.Title level={3} style={{ margin: 0 }}>{employee.full_name}</Typography.Title>
          <Tag color={STATUS_COLORS[employee.status]}>{employee.status}</Tag>
        </Space>
        <Space>
          <Button type="primary" onClick={() => setOpenModal('revision')}>Add revision</Button>
          {!employee.terminated_on && <Button danger onClick={() => setOpenModal('terminate')}>Terminate</Button>}
        </Space>
      </Flex>
      <Descriptions bordered size="small" column={{ xs: 1, md: 2 }}>
        <Descriptions.Item label="Employee code">{employee.employee_code}</Descriptions.Item>
        <Descriptions.Item label="Country">{employee.country.name}</Descriptions.Item>
        <Descriptions.Item label="Department">{employee.department}</Descriptions.Item>
        <Descriptions.Item label="Job title">{employee.job_title}</Descriptions.Item>
        <Descriptions.Item label="Joined">{employee.joined_on}</Descriptions.Item>
        <Descriptions.Item label="Last working day">{employee.terminated_on ?? '—'}</Descriptions.Item>
        <Descriptions.Item label="Bank account">{employee.bank_account}</Descriptions.Item>
        <Descriptions.Item label="Current annual gross">{formatMoney(employee.current_annual_gross)}</Descriptions.Item>
      </Descriptions>
      <Typography.Title level={4} style={{ margin: 0 }}>Salary revisions</Typography.Title>
      <Table
        rowKey="id"
        columns={revisionColumns}
        dataSource={revisions}
        pagination={false}
        locale={{ emptyText: 'No salary revisions yet.' }}
        scroll={{ x: true }}
      />
      <AddRevisionModal employeeId={employee.id} open={openModal === 'revision'} onClose={() => setOpenModal(null)} onSaved={handleSaved} />
      <TerminateModal employee={employee} open={openModal === 'terminate'} onClose={() => setOpenModal(null)} onSaved={handleSaved} />
    </Flex>
  )
}

export default EmployeeDetailPage
