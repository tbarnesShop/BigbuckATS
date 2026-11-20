# frozen_string_literal: true

module Sources
  # Batches `find by id` per model, so lists of N records cost one query per
  # association instead of N. Tenant scoping applies as usual (TenantScoped).
  class RecordById < GraphQL::Dataloader::Source
    def initialize(model)
      @model = model
    end

    def fetch(ids)
      records = @model.where(id: ids.uniq).index_by(&:id)
      ids.map { |id| records[id] }
    end
  end
end
