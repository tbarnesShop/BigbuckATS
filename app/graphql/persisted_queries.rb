# frozen_string_literal: true

# Trusted documents: the web app's queries, registered at build time in
# app/graphql/persisted_queries.json as { "<sha256 of the document>": "<document>" }.
# Browser sessions may only run these, so the browser cannot send arbitrary
# (expensive or probing) queries with a user's session.
module PersistedQueries
  PATH = Rails.root.join("app/graphql/persisted_queries.json")

  module_function

  def all
    @all ||= File.exist?(PATH) ? JSON.parse(File.read(PATH)).freeze : {}.freeze
  end

  def reload!
    @all = nil
  end

  def fetch(id)
    all[id.to_s]
  end

  def digest(document)
    Digest::SHA256.hexdigest(document)
  end
end
