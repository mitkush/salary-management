import { useState } from 'react'
import { Alert, Button, Card, Form, Input, Layout, Typography } from 'antd'
import { api } from './api.js'

function LoginPage({ onLogin }) {
  const [error, setError] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  async function handleFinish(values) {
    setError(null)
    setSubmitting(true)
    try {
      const data = await api('/session', { method: 'POST', body: values })
      onLogin(data.user)
    } catch (err) {
      setError(err.message)
      setSubmitting(false)
    }
  }

  return (
    <Layout style={{ minHeight: '100vh', alignItems: 'center', justifyContent: 'center' }}>
      <Card style={{ width: 360 }}>
        <Typography.Title level={3} style={{ textAlign: 'center' }}>
          Salary Management
        </Typography.Title>
        {error && <Alert type="error" message={error} showIcon style={{ marginBottom: 16 }} />}
        <Form layout="vertical" onFinish={handleFinish} requiredMark={false}>
          <Form.Item
            label="Email"
            name="email_address"
            rules={[{ required: true, message: 'Please enter your email' }]}
          >
            <Input type="email" autoComplete="username" autoFocus />
          </Form.Item>
          <Form.Item
            label="Password"
            name="password"
            rules={[{ required: true, message: 'Please enter your password' }]}
          >
            <Input.Password autoComplete="current-password" />
          </Form.Item>
          <Button type="primary" htmlType="submit" block loading={submitting}>
            Log in
          </Button>
        </Form>
      </Card>
    </Layout>
  )
}

export default LoginPage
