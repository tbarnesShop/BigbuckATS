# Platform metadata, deliberately outside tenant default scopes. One row per template (only "lab" today):
# the compressed lab dataset that DemoTemplate copies into each sandbox. See DemoTemplate.
class DemoTemplateSnapshot < ApplicationRecord
  self.primary_key = "key"
end
