import { useState } from 'react'
import { Alert, DatePicker, Form, Modal, Typography } from 'antd'
import { api } from './api.js'
import { formErrorUpdate } from './formErrors.js'

const FIELD_NAMES = ['terminated_on']

function TerminateModal({ employee, open, onClose, onSaved }) {
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
      await api(`/employees/${employee.id}/termination`, {
        method: 'POST',
        body: { terminated_on: values.terminated_on.format('YYYY-MM-DD') },
      })
      form.resetFields()
      onSaved()
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
      title={`Terminate ${employee.full_name}`}
      open={open}
      onCancel={close}
      onOk={form.submit}
      okText="Terminate"
      okButtonProps={{ danger: true }}
      confirmLoading={saving}
      destroyOnHidden
    >
      <Typography.Paragraph>
        This sets the employee's last working day. It can't be undone or changed later.
      </Typography.Paragraph>
      {error && <Alert type="error" message={error} showIcon style={{ marginBottom: 16 }} />}
      <Form form={form} layout="vertical" onFinish={handleFinish} requiredMark={false}>
        <Form.Item label="Last working day" name="terminated_on" rules={[{ required: true, message: 'Required' }]}>
          <DatePicker style={{ width: '100%' }} />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default TerminateModal
