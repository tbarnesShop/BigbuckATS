# frozen_string_literal: true

class ProcessImportJob < ApplicationJob
  queue_as :imports

  def perform(import_run_id)
    run = ImportRun.unscoped.find(import_run_id)
    Current.set(organization_id: run.organization_id, actor_id: run.actor_id,
                actor_type: run.actor_id ? "user" : "system", source_surface: "import") do
      ImportProcessor.new(ImportRun.find(run.id)).process!
    end
  end
end
