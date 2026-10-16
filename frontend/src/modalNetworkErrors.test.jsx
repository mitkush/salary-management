// @vitest-environment jsdom
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import AddRevisionModal from './AddRevisionModal.jsx'
import TerminateModal from './TerminateModal.jsx'

beforeAll(() => {
  window.matchMedia ??= () => ({ matches: false, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {} })
  window.ResizeObserver ??= class { observe() {} unobserve() {} disconnect() {} }
})

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

function failNetwork() {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
}

function typeDate(label, value) {
  const input = screen.getByLabelText(label)
  fireEvent.mouseDown(input)
  fireEvent.change(input, { target: { value } })
  fireEvent.keyDown(input, { key: 'Enter', code: 'Enter' })
}

describe('modals when the server cannot be reached', () => {
  it('TerminateModal tells HR the termination was not saved', async () => {
    failNetwork()
    render(<TerminateModal employee={{ id: 1, full_name: 'Priya Shah' }} open onClose={() => {}} onSaved={() => {}} />)

    typeDate('Last working day', '2026-10-31')
    fireEvent.click(screen.getByRole('button', { name: 'Terminate' }))

    expect(await screen.findByText(/couldn't reach the server/i)).toBeTruthy()
  })

  it('AddRevisionModal tells HR the revision was not saved', async () => {
    failNetwork()
    render(<AddRevisionModal employeeId={1} open onClose={() => {}} onSaved={() => {}} />)

    typeDate('Effective date', '2026-11-01')
    fireEvent.change(screen.getByLabelText('Annual base (USD)'), { target: { value: '70000' } })
    fireEvent.change(screen.getByLabelText('Annual allowances (USD)'), { target: { value: '7000' } })
    fireEvent.change(screen.getByLabelText('Annual deductions (USD)'), { target: { value: '2800' } })
    fireEvent.mouseDown(screen.getByLabelText('Reason'))
    fireEvent.click(await screen.findByTitle('increment'))
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(await screen.findByText(/couldn't reach the server/i)).toBeTruthy()
  })
})
