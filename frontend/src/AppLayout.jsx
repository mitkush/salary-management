import { useState } from 'react'
import { Alert, Button, Layout, Menu, Space, Typography } from 'antd'
import { Link, Outlet, useLocation } from 'react-router'
import { api } from './api.js'

const { Header, Content } = Layout

function AppLayout({ user, onLogout }) {
  const [loggingOut, setLoggingOut] = useState(false)
  const [error, setError] = useState(null)
  const location = useLocation()

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

  const selectedKey = ['dashboard', 'employees', 'import', 'countries'].find((key) => location.pathname.startsWith(`/${key}`)) ?? null

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        <Typography.Title level={4} style={{ color: '#fff', margin: 0, whiteSpace: 'nowrap' }}>
          Salary Management
        </Typography.Title>
        <Menu
          theme="dark"
          mode="horizontal"
          selectedKeys={selectedKey ? [selectedKey] : []}
          items={[
            { key: 'dashboard', label: <Link to="/dashboard">Dashboard</Link> },
            { key: 'employees', label: <Link to="/employees">Employees</Link> },
            { key: 'import', label: <Link to="/import">Import</Link> },
            { key: 'countries', label: <Link to="/countries">Countries</Link> },
          ]}
          style={{ flex: 1, minWidth: 0 }}
        />
        <Space>
          <Typography.Text style={{ color: '#fff' }}>{user.email_address}</Typography.Text>
          <Button onClick={handleLogout} loading={loggingOut}>
            Log out
          </Button>
        </Space>
      </Header>
      <Content style={{ padding: 24 }}>
        {error && <Alert type="error" message={error} showIcon closable style={{ marginBottom: 16 }} />}
        <Outlet />
      </Content>
    </Layout>
  )
}

export default AppLayout
