# frozen_string_literal: true

module V1
  class AnalyticsController < ApplicationController
    before_action :require_tenant!

    def funnel
      render json: RecruitingAnalytics.funnel(job_id: params[:job_id])
    end

    def sourcing
      render json: RecruitingAnalytics.sourcing
    end

    # Outreach funnel for a window (default last 30 days): GET /analytics/outreach?from=&to=&sequence_id=
    def outreach
      to = params[:to].present? ? Time.zone.parse(params[:to]) : Time.current
      from = params[:from].present? ? Time.zone.parse(params[:from]) : to - 30.days
      raise ArgumentError, "invalid_range" if from.nil? || to.nil? || from >= to || (to - from) > 366.days

      render json: OutreachFunnel.call(from: from, to: to, sequence_id: params[:sequence_id].presence)
    rescue ArgumentError => e
      render_problem(status: :unprocessable_entity, code: "invalid_range", title: e.message)
    end

    # Daily snapshots: GET /analytics/outreach_snapshots?from=YYYY-MM-DD&to=YYYY-MM-DD&sequence_id=
    def outreach_snapshots
      to = params[:to].present? ? Date.parse(params[:to]) : Date.current
      from = params[:from].present? ? Date.parse(params[:from]) : to - 30
      key = params[:sequence_id].present? ? "seq:#{params[:sequence_id]}" : OutreachSnapshot::ORG
      rows = OutreachSnapshot.where(scope_key: key, snapshot_on: from..to).order(:snapshot_on)
      render json: { data: rows.map { |r| { "date" => r.snapshot_on, "sequence_id" => r.sequence_id, "metrics" => r.metrics } } }
    rescue Date::Error
      render_problem(status: :unprocessable_entity, code: "invalid_range", title: "invalid_range")
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
