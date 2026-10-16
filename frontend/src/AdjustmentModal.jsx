import { useState } from 'react'
import { Alert, Form, Input, InputNumber, Modal } from 'antd'
import { api } from './api.js'
import { formErrorUpdate } from './formErrors.js'

const FIELD_NAMES = ['bonus', 'one_time_deduction', 'adjustment_note']

function AdjustmentModal({ month, entry, onClose, onSaved }) {
  const [form] = Form.useForm()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)

  async function handleFinish(values) {
    setSaving(true)
    setError(null)
    try {
      onSaved(await api(`/payroll_runs/${month}/entries/${entry.id}`, { method: 'PATCH', body: { entry: values } }))
    } catch (err) {
      const { fields, message } = formErrorUpdate(err, FIELD_NAMES)
      form.setFields(fields)
      setError(message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title={`Adjust ${entry.full_name}`} open onCancel={onClose} onOk={form.submit} okText="Save" confirmLoading={saving} destroyOnHidden>
      {error && <Alert type="error" message={error} showIcon style={{ marginBottom: 16 }} />}
      <Form
        form={form}
        layout="vertical"
        onFinish={handleFinish}
        requiredMark={false}
        initialValues={{
          bonus: Number(entry.bonus),
          one_time_deduction: Number(entry.one_time_deduction),
          adjustment_note: entry.adjustment_note ?? '',
        }}
      >
        <Form.Item label="One-time bonus (USD, taxed)" name="bonus" rules={[{ required: true, message: 'Required' }]}>
          <InputNumber min={0} precision={2} style={{ width: '100%' }} />
        </Form.Item>
        <Form.Item label="One-time deduction (USD, after tax)" name="one_time_deduction" rules={[{ required: true, message: 'Required' }]}>
          <InputNumber min={0} precision={2} style={{ width: '100%' }} />
        </Form.Item>
        <Form.Item label="Note" name="adjustment_note">
          <Input maxLength={255} placeholder="e.g. Loan recovery, joining bonus" />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default AdjustmentModal
