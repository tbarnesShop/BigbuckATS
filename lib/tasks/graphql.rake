# frozen_string_literal: true

namespace :graphql do
  namespace :schema do
    desc "Write the committed GraphQL schema (schema.graphql) from BigbuckSchema"
    task dump: :environment do
      path = Rails.root.join("schema.graphql")
      File.write(path, BigbuckSchema.to_definition)
      puts "Wrote #{path}"
    end
  end
end
