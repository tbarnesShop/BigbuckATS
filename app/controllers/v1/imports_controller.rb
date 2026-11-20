# frozen_string_literal: true

module V1
  class ImportsController < ApplicationController
    before_action :require_tenant!

    def index
      rows = ImportRun.order(created_at: :desc).limit(50)
      render json: { data: rows.map { |r| serialize_run(r) } }
    end

    def show
      run = ImportRun.find(params[:id])
      render json: serialize_run(run, include_rows: true)
    end

    def create
      with_idempotency do
        entity = import_params[:entity].presence || "people"
        raise ArgumentError, "unsupported_entity" unless entity == "people"

        csv_string = resolve_csv_string!
        mapping = if import_params[:field_mapping].present?
                    import_params[:field_mapping].to_unsafe_h
        else
                    CsvPeopleImporter::DEFAULT_MAPPING
        end
        dry_run = ActiveModel::Type::Boolean.new.cast(import_params[:dry_run]) || false
        source_system = import_params[:source_system].presence || "csv"

        async = import_params.key?(:async) ? ActiveModel::Type::Boolean.new.cast(import_params[:async]) : nil
        result = CsvPeopleImporter.call(
          csv_string: csv_string,
          field_mapping: mapping,
          source_system: source_system,
          dry_run: dry_run,
          async: async
        )
        # Large imports are processed in the background; poll GET /v1/imports/:id.
        status = result.run.status == "queued" ? :accepted : :created
        render json: serialize_run(result.run, include_rows: status == :created), status: status
      end
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_import", title: error.message)
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def import_params
      params.require(:import).permit(:entity, :csv, :dry_run, :async, :source_system, field_mapping: {})
    end

    def resolve_csv_string!
      csv = import_params[:csv].to_s
      raise ArgumentError, "csv_required" if csv.blank?

      csv
    end

    def serialize_run(run, include_rows: false)
      payload = run.as_json(
        only: %i[
          id organization_id source entity status field_mapping row_count
          created_count updated_count error_count processed_count finished_at actor_id created_at updated_at
        ]
      )
      return payload unless include_rows

      payload.merge(
        "rows" => run.import_rows.order(:row_number).limit(500).map { |row|
          row.as_json(
            only: %i[id row_number source_id resource_type resource_id status error_message mapped]
          )
        }
      )
    end
  end
end
