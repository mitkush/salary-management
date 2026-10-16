import { useState } from 'react'
import { Button, Layout, Space, Typography } from 'antd'
import { api } from './api.js'

const { Header, Content } = Layout

function AppLayout({ user, onLogout }) {
  const [loggingOut, setLoggingOut] = useState(false)

  async function handleLogout() {
    setLoggingOut(true)
    try {
      await api('/session', { method: 'DELETE' })
    } finally {
      onLogout()
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
        <Typography.Text>Welcome.</Typography.Text>
      </Content>
    </Layout>
  )
}

export default AppLayout
