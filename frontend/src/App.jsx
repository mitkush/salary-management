import { useEffect, useState } from 'react'
import { Alert, Flex, Spin } from 'antd'
import { api, setUnauthorizedHandler } from './api.js'
import AppLayout from './AppLayout.jsx'
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

  return <AppLayout user={user} onLogout={() => setUser(null)} />
}

export default App
