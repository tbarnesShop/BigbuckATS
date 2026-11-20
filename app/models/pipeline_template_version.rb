# frozen_string_literal: true

class PipelineTemplateVersion < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :pipeline_template
end
