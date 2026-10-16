import { Layout, Typography } from 'antd'

const { Header, Content } = Layout

function App() {
  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header>
        <Typography.Title level={4} style={{ color: '#fff', margin: '16px 0' }}>
          Salary Management
        </Typography.Title>
      </Header>
      <Content style={{ padding: 24 }}>
        <Typography.Text>Setup complete.</Typography.Text>
      </Content>
    </Layout>
  )
}

export default App
