# frozen_string_literal: true

# POST /graphql — the GraphQL surface for the web app and agents. Same identity,
# same permissions and same services as REST; every write goes through
# ChangeWriter, so audit does not depend on the transport.
#
# Body: { "query": "...", "variables": {...}, "operationName": "..." }
#   or  { "id": "<sha256>" } / { "extensions": { "persistedQuery": { "sha256Hash": "..." } } }
class GraphqlController < ApplicationController
  def execute
    return render_problem(status: :unauthorized, code: "unauthenticated", title: "Send a bearer token.") unless current_principal

    document, persisted = resolve_document
    return if performed?

    result = BigbuckSchema.execute(
      document,
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      max_complexity: persisted ? BigbuckSchema.max_complexity : BigbuckSchema::AD_HOC_MAX_COMPLEXITY,
      context: {
        principal: current_principal,
        viewer: PrincipalViewer.new(current_principal),
        request_id: Current.request_id
      }
    )
    render json: result
  end

  private

  def resolve_document
    id = params[:id].presence || params.dig(:extensions, :persistedQuery, :sha256Hash).presence
    if id
      document = PersistedQueries.fetch(id)
      unless document
        render_problem(status: :not_found, code: "persisted_query_not_found", title: "Unknown persisted query #{id}.")
        return [ nil, false ]
      end
      return [ document, true ]
    end

    document = params[:query].to_s
    if document.blank?
      render_problem(status: :unprocessable_entity, code: "query_required", title: "Send a query or a persisted query id.")
      return [ nil, false ]
    end

    # A registered document sent as text still counts as persisted.
    return [ document, true ] if PersistedQueries.fetch(PersistedQueries.digest(document))

    if browser_session? && Rails.configuration.x.graphql_persisted_only_for_sessions
      render_problem(status: :forbidden, code: "persisted_query_required",
                     title: "Browser sessions may only run the app's registered queries.")
      return [ nil, false ]
    end

    [ document, false ]
  end

  def browser_session?
    current_principal.credential&.kind == "session"
  end

  def prepare_variables(variables)
    case variables
    when String then variables.present? ? JSON.parse(variables) : {}
    when Hash then variables
    when ActionController::Parameters then variables.to_unsafe_hash
    when nil then {}
    else raise ArgumentError, "Unexpected variables: #{variables.inspect}"
    end
  end
end
