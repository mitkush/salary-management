import { useEffect, useState } from 'react'
import { Alert, Button, Flex, Result, Spin } from 'antd'
import { Link, Navigate, Route, Routes } from 'react-router'
import { api, setUnauthorizedHandler } from './api.js'
import AppLayout from './AppLayout.jsx'
import DashboardPage from './DashboardPage.jsx'
import EmployeeDetailPage from './EmployeeDetailPage.jsx'
import EmployeesPage from './EmployeesPage.jsx'
import LoginPage from './LoginPage.jsx'

function App() {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setUnauthorizedHandler(() => setUser(null))
    api('/session')
      .then((data) => setUser(data.user))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <Flex style={{ minHeight: '100vh' }} align="center" justify="center">
        <Spin size="large" />
      </Flex>
    )
  }

  if (error) {
    return <Alert type="error" message={error} showIcon style={{ margin: 24 }} />
  }

  if (!user) return <LoginPage onLogin={setUser} />

  return (
    <Routes>
      <Route element={<AppLayout user={user} onLogout={() => setUser(null)} />}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="employees" element={<EmployeesPage />} />
        <Route path="employees/:id" element={<EmployeeDetailPage />} />
        <Route
          path="*"
          element={
            <Result
              status="404"
              title="Page not found"
              extra={<Link to="/dashboard"><Button type="primary">Go to dashboard</Button></Link>}
            />
          }
        />
      </Route>
    </Routes>
  )
}

export default App
