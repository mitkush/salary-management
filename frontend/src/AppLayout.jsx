import { useState } from 'react'
import { Alert, Button, Layout, Space, Typography } from 'antd'
import { api } from './api.js'

const { Header, Content } = Layout

function AppLayout({ user, onLogout }) {
  const [loggingOut, setLoggingOut] = useState(false)
  const [error, setError] = useState(null)

  async function handleLogout() {
    setError(null)
    setLoggingOut(true)
    try {
      await api('/session', { method: 'DELETE' })
      onLogout()
    } catch (err) {
      setError(`Logout failed: ${err.message}`)
      setLoggingOut(false)
    }
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Typography.Title level={4} style={{ color: '#fff', margin: 0 }}>
          Salary Management
        </Typography.Title>
        <Space>
          <Typography.Text style={{ color: '#fff' }}>{user.email_address}</Typography.Text>
          <Button onClick={handleLogout} loading={loggingOut}>
            Log out
          </Button>
        </Space>
      </Header>
      <Content style={{ padding: 24 }}>
        {error && <Alert type="error" message={error} showIcon closable style={{ marginBottom: 16 }} />}
        <Typography.Text>Welcome.</Typography.Text>
      </Content>
    </Layout>
  )
}

export default AppLayout
