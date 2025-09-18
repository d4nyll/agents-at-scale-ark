"use client"

import type React from "react"
import { useState, useEffect, forwardRef, useImperativeHandle } from "react"
import { toast } from "@/components/ui/use-toast"
import { ToastAction } from "@/components/ui/toast"
import { ModelEditor } from "@/components/editors"
import { modelsService, agentsService, type Model, type Agent, type ModelCreateRequest, type ModelUpdateRequest } from "@/lib/services"
import { ModelCard } from "@/components/cards"
import { useDelayedLoading } from "@/lib/hooks"
import { ModelRow } from "@/components/rows/model-row"
import { ToggleSwitch, type ToggleOption } from "@/components/ui/toggle-switch"

interface ModelsSectionProps {
  namespace: string
}

export const ModelsSection = forwardRef<{ openAddEditor: () => void }, ModelsSectionProps>(function ModelsSection({ namespace }, ref) {
  const [models, setModels] = useState<Model[]>([])
  const [agents, setAgents] = useState<Agent[]>([])
  const [modelEditorOpen, setModelEditorOpen] = useState(false)
  const [loading, setLoading] = useState(true)
  const showLoading = useDelayedLoading(loading)
  const [showCompactView, setShowCompactView] = useState(false)
  const [shownHelpToast, setShownHelpToast] = useState<string[]>([])
  
  const viewOptions: ToggleOption[] = [
    { id: "compact", label: "compact view", active: !showCompactView },
    { id: "card", label: "card view", active: showCompactView }
  ]

  useImperativeHandle(ref, () => ({
    openAddEditor: () => setModelEditorOpen(true)
  }));

  useEffect(() => {
    const loadData = async () => {
      setLoading(true)
      setShownHelpToast([]) // Reset toast state when namespace changes
      try {
        const [modelsData, agentsData] = await Promise.all([
          modelsService.getAll(namespace),
          agentsService.getAll(namespace)
        ])
        setModels(modelsData)
        setAgents(agentsData)
      } catch (error) {
        console.error("Failed to load data:", error)
        toast({
          variant: "destructive",
          title: "Failed to Load Data",
          description: error instanceof Error ? error.message : "An unexpected error occurred"
        })
      } finally {
        setLoading(false)
      }
    }

    loadData()
  }, [namespace])

  // Show toast when no models exist, no default model exists, or the default model has a status of 'error'
  useEffect(() => {
    if (!loading) {
      if (models.length === 0) {
        if (!shownHelpToast.includes("no-models")) {
          toast({
            variant: "default",
            title: "No Models Found",
            description: "Get started by creating your first model. We support all OpenAI API compatible models (including Azure OpenAI, Claude, Gemini), and AWS Bedrock.",
            action: (
              <ToastAction
                altText="Create a new model"
                onClick={() => setModelEditorOpen(true)}
              >
                Create Model
              </ToastAction>
            )
          })
          setShownHelpToast(prev => [...prev, "no-models"])
        }
      // If there are no default model
      } else if (!models.find(m => m.name === 'default')) {
        if (!shownHelpToast.includes("no-default-model")) {
          toast({
            variant: "default",
            title: "No Default Model",
            description: "Create a default model to get started. We support all OpenAI API compatible models (including Azure OpenAI, Claude, Gemini), and AWS Bedrock.",
            action: (
              <ToastAction
                altText="Create a default model"
                onClick={() => setModelEditorOpen(true)}
              >
                Create Model
              </ToastAction>
            )
          })
          setShownHelpToast(prev => [...prev, "no-default-model"])
        }
      // If the default model has an error
      } else if (models.find(m => m.name === 'default')?.status === 'error') {
        if (!shownHelpToast.includes("default-model-error")) {
        toast({
          variant: "default",
          title: "Default Model Error",
          description: "Your default model has an error. Create a new model to get started. We support all OpenAI API compatible models (including Azure OpenAI, Claude, Gemini), and AWS Bedrock.",
          action: (
            <ToastAction
              altText="Create a new model"
              onClick={() => setModelEditorOpen(true)}
            >
              Create Model
            </ToastAction>
          )
          })
          setShownHelpToast(prev => [...prev, "default-model-error"])
        }
      }
    }
  }, [loading, models, shownHelpToast])

  const handleSaveModel = async (model: ModelCreateRequest | (ModelUpdateRequest & { id: string })) => {
    try {
      if ('id' in model) {
        // Update existing model
        const { id, ...updateData } = model
        await modelsService.updateById(namespace, id, updateData)
        toast({
          variant: "success",
          title: "Model Updated",
          description: `Successfully updated model`
        })
      } else {
        // Create new model
        await modelsService.create(namespace, model)
        toast({
          variant: "success",
          title: "Model Created",
          description: `Successfully created ${model.name}`
        })
      }
      // Reload data
      const updatedModels = await modelsService.getAll(namespace)
      setModels(updatedModels)
    } catch (error) {
      toast({
        variant: "destructive",
        title: 'id' in model ? "Failed to Update Model" : "Failed to Create Model",
        description: error instanceof Error ? error.message : "An unexpected error occurred"
      })
    }
  }

  const handleDeleteModel = async (id: string) => {
    try {
      const model = models.find(m => m.id === id)
      if (!model) {
        throw new Error("Model not found")
      }
      await modelsService.deleteById(namespace, id)
      toast({
        variant: "success",
        title: "Model Deleted",
        description: `Successfully deleted ${model.name}`
      })
      // Reload data
      const [updatedModels, updatedAgents] = await Promise.all([
        modelsService.getAll(namespace),
        agentsService.getAll(namespace)
      ])
      setModels(updatedModels)
      setAgents(updatedAgents)
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Failed to Delete Model",
        description: error instanceof Error ? error.message : "An unexpected error occurred"
      })
    }
  }

  if (showLoading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="text-center py-8">Loading...</div>
      </div>
    )
  }

  return (
    <>
      <div className="flex h-full flex-col">
        <div className="flex items-center justify-end px-6 py-3">
          <ToggleSwitch
            options={viewOptions}
            onChange={(id) => setShowCompactView(id === "card")}
          />
        </div>
        
        <main className="flex-1 overflow-auto px-6 py-0">
          {showCompactView && (
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 pb-6">
              {models.map((model) => (
                <ModelCard 
                  key={model.id} 
                  model={model} 
                  agents={agents} 
                  onUpdate={handleSaveModel}
                  onDelete={handleDeleteModel}
                  namespace={namespace}
                />
              ))}
            </div>
          )}
          
          {!showCompactView && (
            <div className="flex flex-col gap-3">
              {models.map((model) => (
                <ModelRow
                  key={model.id} 
                  model={model} 
                  agents={agents} 
                  onUpdate={handleSaveModel}
                  onDelete={handleDeleteModel}
                  namespace={namespace}
                />
              ))}
            </div>
          )}
        </main>
      </div>
      
      <ModelEditor
        open={modelEditorOpen}
        onOpenChange={setModelEditorOpen}
        model={null}
        onSave={handleSaveModel}
        namespace={namespace}
      />
    </>
  )
});