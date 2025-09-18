import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { render, waitFor } from '@testing-library/react'
import { ModelsSection } from '@/components/sections/models-section'
import { modelsService, agentsService, type Model } from '@/lib/services'
import { toast } from '@/components/ui/use-toast'

// Mock the services
vi.mock('@/lib/services', () => ({
  modelsService: {
    getAll: vi.fn(),
    create: vi.fn(),
    updateById: vi.fn(),
    deleteById: vi.fn(),
  },
  agentsService: {
    getAll: vi.fn(),
  },
}))

// Mock the toast system
vi.mock('@/components/ui/use-toast', () => ({
  toast: vi.fn(),
}))

describe('ModelsSection', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(modelsService.getAll).mockResolvedValue([])
    vi.mocked(agentsService.getAll).mockResolvedValue([])
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  describe('Default model toast behavior', () => {

    const readyDefaultModel = {
      id: 'default',
      name: 'default',
      type: 'azure',
      model: 'gpt-4.1-mini',
      status: 'ready',
    } as Model

    const errorDefaultModel = {
      id: 'default',
      name: 'default',
      type: 'azure',
      model: 'gpt-4.1-mini',
      status: 'error',
    } as Model

    const readyNonDefaultModel = {
      id: 'non-default',
      name: 'non-default',
      type: 'azure',
      model: 'gpt-4.1-mini',
      status: 'ready',
    } as Model

    const errorNonDefaultModel = {
      id: 'non-default',
      name: 'non-default',
      type: 'azure',
      model: 'gpt-4.1-mini',
      status: 'error',
    } as Model

    it('should show "No Models Found" toast when no models exist', async () => {
      render(<ModelsSection namespace="default" />)
      await waitFor(() => {
        expect(toast).toHaveBeenCalledWith({
          variant: 'default',
          title: 'No Models Found',
          description: 'Get started by creating your first model. We support all OpenAI API compatible models (including Azure OpenAI, Claude, Gemini), and AWS Bedrock.',
          action: expect.any(Object),
        })
      })
    })

    it('should show "No Default Model" toast when no default model exists', async () => {
      vi.mocked(modelsService.getAll).mockResolvedValue([readyNonDefaultModel])
      render(<ModelsSection namespace="default" />)
      await waitFor(() => {
        expect(toast).toHaveBeenCalledWith({
          variant: 'default',
          title: 'No Default Model',
          description: 'Create a default model to get started. We support all OpenAI API compatible models (including Azure OpenAI, Claude, Gemini), and AWS Bedrock.',
          action: expect.any(Object),
        })
      })
    })

    it('should show "Default Model Error" toast when default model has error status', async () => {
      vi.mocked(modelsService.getAll).mockResolvedValue([errorDefaultModel, readyNonDefaultModel])
      render(<ModelsSection namespace="default" />)
      await waitFor(() => {
        expect(toast).toHaveBeenCalledWith({
          variant: 'default',
          title: 'Default Model Error',
          description: 'Your default model has an error. Create a new model to get started. We support all OpenAI API compatible models (including Azure OpenAI, Claude, Gemini), and AWS Bedrock.',
          action: expect.any(Object),
        })
      })
    })

    it('should not show toast when ready default model exists', async () => {
      vi.mocked(modelsService.getAll).mockResolvedValue([readyDefaultModel, errorNonDefaultModel])
      render(<ModelsSection namespace="default" />)
      await waitFor(() => {
        expect(modelsService.getAll).toHaveBeenCalled()
      })
      expect(toast).not.toHaveBeenCalled()
    })

    it('should not show duplicate toasts on re-renders', async () => {
      const { rerender } = render(<ModelsSection namespace="default" />)
      await waitFor(() => {
        expect(toast).toHaveBeenCalledTimes(1)
      })
      rerender(<ModelsSection namespace="default" />)
      expect(toast).toHaveBeenCalledTimes(1)
    })

    it('should reset toast state when namespace changes', async () => {
      const { rerender } = render(<ModelsSection namespace="default" />)
      await waitFor(() => {
        expect(toast).toHaveBeenCalledTimes(1)
      })
      // Change namespace
      rerender(<ModelsSection namespace="new-namespace" />)
      await waitFor(() => {
        expect(toast).toHaveBeenCalledTimes(2)
      })
    })
  })
})
