import { useState } from 'react'
import { Alert, Form, InputNumber, Modal } from 'antd'
import { api } from './api.js'
import { formErrorUpdate } from './formErrors.js'

const FIELD_NAMES = ['tax_rate_percent']

function TaxRateModal({ country, onClose, onSaved }) {
  const [form] = Form.useForm()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)

  async function handleFinish(values) {
    setSaving(true)
    setError(null)
    try {
      const updated = await api(`/countries/${country.id}`, { method: 'PATCH', body: { country: values } })
      onSaved(updated)
    } catch (err) {
      const { fields, message } = formErrorUpdate(err, FIELD_NAMES)
      form.setFields(fields)
      setError(message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal
      title={`Tax rate for ${country.name}`}
      open
      onCancel={onClose}
      onOk={form.submit}
      okText="Save"
      confirmLoading={saving}
      destroyOnHidden
    >
      {error && <Alert type="error" message={error} showIcon style={{ marginBottom: 16 }} />}
      <Form
        form={form}
        layout="vertical"
        onFinish={handleFinish}
        requiredMark={false}
        initialValues={{ tax_rate_percent: Number(country.tax_rate_percent) }}
      >
        <Form.Item label="Tax rate" name="tax_rate_percent" rules={[{ required: true, message: 'Required' }]}>
          <InputNumber min={0} max={100} precision={2} step={0.5} suffix="%" style={{ width: '100%' }} />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default TaxRateModal
