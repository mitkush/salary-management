import { useState } from 'react'
import { Alert, DatePicker, Form, InputNumber, Modal, Select } from 'antd'
import { api } from './api.js'

const REASONS = ['increment', 'promotion', 'correction', 'other'].map((reason) => ({ value: reason, label: reason }))
const amountRules = [{ required: true, message: 'Required' }]

function AddRevisionModal({ employeeId, open, onClose, onSaved }) {
  const [form] = Form.useForm()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)

  function close() {
    form.resetFields()
    setError(null)
    onClose()
  }

  async function handleFinish(values) {
    setSaving(true)
    setError(null)
    try {
      await api(`/employees/${employeeId}/salary_revisions`, {
        method: 'POST',
        body: { salary_revision: { ...values, effective_on: values.effective_on.format('YYYY-MM-DD') } },
      })
      form.resetFields()
      onSaved()
    } catch (err) {
      if (err.fieldErrors().length > 0) form.setFields(err.fieldErrors())
      else setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title="Add salary revision" open={open} onCancel={close} onOk={form.submit} okText="Save" confirmLoading={saving} destroyOnHidden>
      {error && <Alert type="error" message={error} showIcon style={{ marginBottom: 16 }} />}
      <Form form={form} layout="vertical" onFinish={handleFinish} requiredMark={false}>
        <Form.Item label="Effective date" name="effective_on" rules={[{ required: true, message: 'Required' }]}>
          <DatePicker style={{ width: '100%' }} />
        </Form.Item>
        <Form.Item label="Annual base (USD)" name="annual_base" rules={amountRules}>
          <InputNumber min={0} precision={2} style={{ width: '100%' }} />
        </Form.Item>
        <Form.Item label="Annual allowances (USD)" name="annual_allowances" rules={amountRules}>
          <InputNumber min={0} precision={2} style={{ width: '100%' }} />
        </Form.Item>
        <Form.Item label="Annual deductions (USD)" name="annual_deductions" rules={amountRules}>
          <InputNumber min={0} precision={2} style={{ width: '100%' }} />
        </Form.Item>
        <Form.Item label="Reason" name="reason" rules={[{ required: true, message: 'Required' }]}>
          <Select options={REASONS} />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default AddRevisionModal
