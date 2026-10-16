import { useEffect, useState } from 'react'
import { Alert, Button, Card, Col, DatePicker, Flex, Modal, Row, Space, Statistic, Table, Tag, Typography, message } from 'antd'
import { useSearchParams } from 'react-router'
import { api, download } from './api.js'
import AdjustmentModal from './AdjustmentModal.jsx'
import { formErrorUpdate } from './formErrors.js'
import { formatMoney } from './format.js'
import { findRun, missingRunMessage, monthLabel, toMonthParam } from './payrollMonth.js'
import { saveFile } from './saveFile.js'

function runTags(run) {
  return (
    <Space size={4}>
      {run.locked ? <Tag>Locked</Tag> : <Tag color="green">Open</Tag>}
      {run.outdated && <Tag color="orange">Outdated</Tag>}
    </Space>
  )
}

function PayrollPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [runsReload, setRunsReload] = useState(0)
  const [entriesReload, setEntriesReload] = useState(0)
  const [runs, setRuns] = useState({ key: null, data: [], error: null })
  const [entries, setEntries] = useState({ key: null, data: [], meta: { page: 1, per_page: 25, total: 0 }, error: null })
  const [pickedMonth, setPickedMonth] = useState(null)
  const [generating, setGenerating] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [actionError, setActionError] = useState(null)
  const [editing, setEditing] = useState(null)
  const [modal, modalHolder] = Modal.useModal()
  const [messageApi, messageHolder] = message.useMessage()

  const month = searchParams.get('month') ?? runs.data[0]?.month ?? null
  const page = searchParams.get('page') ?? '1'
  const run = month ? findRun(runs.data, month) : undefined
  const entriesKey = `${month}|${page}|${entriesReload}`

  useEffect(() => {
    let ignore = false
    api('/payroll_runs')
      .then((data) => { if (!ignore) setRuns({ key: runsReload, data, error: null }) })
      .catch((err) => { if (!ignore) setRuns((previous) => ({ ...previous, key: runsReload, error: err.message })) })
    return () => { ignore = true }
  }, [runsReload])

  useEffect(() => {
    if (!run) return
    let ignore = false
    const [entriesMonth, entriesPage] = entriesKey.split('|')
    api(`/payroll_runs/${entriesMonth}/entries`, { params: { page: entriesPage } })
      .then((data) => { if (!ignore) setEntries({ ...data, key: entriesKey, error: null }) })
      .catch((err) => { if (!ignore) setEntries((previous) => ({ ...previous, key: entriesKey, error: err.message })) })
    return () => { ignore = true }
  }, [entriesKey, run])

  function selectMonth(value, nextPage = 1) {
    setSearchParams({ month: value, page: String(nextPage) })
  }

  async function generate(target) {
    setGenerating(true)
    setActionError(null)
    try {
      await api(`/payroll_runs/${target}`, { method: 'PUT' })
      messageApi.success(`Payroll for ${monthLabel(target)} generated.`)
      selectMonth(target)
      setRunsReload((count) => count + 1)
      setEntriesReload((count) => count + 1)
    } catch (err) {
      setActionError(formErrorUpdate(err, []).message)
    } finally {
      setGenerating(false)
    }
  }

  function handleGenerate() {
    if (!findRun(runs.data, pickedMonth)) return generate(pickedMonth)
    modal.confirm({
      title: `Recalculate ${monthLabel(pickedMonth)}?`,
      content: 'Amounts are refreshed from current salaries, leavers and tax rates. Bonuses, deductions and notes are kept.',
      okText: 'Recalculate',
      onOk: () => generate(pickedMonth),
    })
  }

  async function handleExport() {
    setExporting(true)
    setActionError(null)
    try {
      saveFile(await download(`/payroll_runs/${month}/export`))
    } catch (err) {
      setActionError(formErrorUpdate(err, []).message)
    } finally {
      setExporting(false)
    }
  }

  function handleSaved(entry) {
    setEditing(null)
    messageApi.success(`${entry.full_name} updated. Net is now ${formatMoney(entry.net)}.`)
    setRunsReload((count) => count + 1)
    setEntriesReload((count) => count + 1)
  }

  const entryColumns = [
    { title: 'Code', dataIndex: 'employee_code' },
    { title: 'Name', dataIndex: 'full_name' },
    { title: 'Bank account', dataIndex: 'bank_account' },
    { title: 'Days', dataIndex: 'days_worked', align: 'right' },
    { title: 'Gross', dataIndex: 'monthly_gross', align: 'right', render: formatMoney },
    { title: 'Bonus', dataIndex: 'bonus', align: 'right', render: formatMoney },
    { title: 'Deductions', dataIndex: 'monthly_deductions', align: 'right', render: formatMoney },
    { title: 'One-time deduction', dataIndex: 'one_time_deduction', align: 'right', render: formatMoney },
    { title: 'Tax', dataIndex: 'tax', align: 'right', render: formatMoney },
    {
      title: 'Net',
      dataIndex: 'net',
      align: 'right',
      render: (net) => <Typography.Text type={Number(net) < 0 ? 'danger' : undefined}>{formatMoney(net)}</Typography.Text>,
    },
    { title: 'Note', dataIndex: 'adjustment_note', render: (note) => note ?? '' },
    ...(run && !run.locked
      ? [{ title: '', key: 'edit', render: (_, entry) => <Button size="small" onClick={() => setEditing(entry)}>Edit</Button> }]
      : []),
  ]

  return (
    <Flex vertical gap={16}>
      {modalHolder}
      {messageHolder}
      <Typography.Title level={3} style={{ margin: 0 }}>Payroll</Typography.Title>
      <Space wrap>
        <DatePicker picker="month" placeholder="Pick a month" onChange={(date) => setPickedMonth(date ? toMonthParam(date.toDate()) : null)} />
        <Button type="primary" onClick={handleGenerate} disabled={!pickedMonth || generating} loading={generating}>
          Generate payroll
        </Button>
      </Space>
      {actionError && <Alert type="error" message={actionError} showIcon closable onClose={() => setActionError(null)} />}
      {runs.error && <Alert type="error" message={runs.error} showIcon />}

      <Table
        rowKey="month"
        size="small"
        loading={runs.key !== runsReload}
        dataSource={runs.data}
        pagination={false}
        locale={{ emptyText: 'No payroll runs yet. Pick a month and generate the first one.' }}
        onRow={(row) => ({ onClick: () => selectMonth(row.month), style: { cursor: 'pointer' } })}
        rowClassName={(row) => (row.month === month ? 'ant-table-row-selected' : '')}
        columns={[
          { title: 'Month', dataIndex: 'month', render: monthLabel },
          { title: 'Employees', dataIndex: 'entries_count', align: 'right' },
          { title: 'Net total', dataIndex: ['totals', 'net'], align: 'right', render: formatMoney },
          { title: 'Status', key: 'status', render: (_, row) => runTags(row) },
        ]}
      />

      {month && !run && runs.key === runsReload && !runs.error && (
        <Alert type="info" showIcon message={missingRunMessage(month)} />
      )}
      {run && (
        <Card
          title={<Space>{monthLabel(run.month)}{runTags(run)}</Space>}
          extra={<Button onClick={handleExport} loading={exporting}>Export to Excel</Button>}
        >
          <Flex vertical gap={16}>
            {run.outdated && (
              <Alert type="warning" showIcon message="Changes after last generation, please recalculate." />
            )}
            {run.locked && <Alert type="info" showIcon message="This month is locked and read-only." />}
            <Row gutter={16}>
              <Col xs={8}><Statistic title="Gross" value={formatMoney(run.totals.gross)} /></Col>
              <Col xs={8}><Statistic title="Tax" value={formatMoney(run.totals.tax)} /></Col>
              <Col xs={8}><Statistic title="Net" value={formatMoney(run.totals.net)} /></Col>
            </Row>
            {entries.error && <Alert type="error" message={entries.error} showIcon />}
            <Table
              rowKey="id"
              size="small"
              columns={entryColumns}
              dataSource={entries.key === entriesKey ? entries.data : []}
              loading={entries.key !== entriesKey}
              locale={{ emptyText: 'No entries this month.' }}
              scroll={{ x: true }}
              pagination={{
                current: Number(page),
                pageSize: entries.meta.per_page,
                total: entries.meta.total,
                showSizeChanger: false,
                showTotal: (total) => `${total} entries`,
                onChange: (nextPage) => selectMonth(month, nextPage),
              }}
            />
          </Flex>
        </Card>
      )}
      {editing && <AdjustmentModal month={month} entry={editing} onClose={() => setEditing(null)} onSaved={handleSaved} />}
    </Flex>
  )
}

export default PayrollPage
