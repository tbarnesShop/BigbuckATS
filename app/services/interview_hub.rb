# frozen_string_literal: true

# Interviews across jobs for the interviews hub. `tab` narrows the list:
#   upcoming  scheduled and still ahead
#   schedule  waiting to be scheduled or needing attention
#   feedback  ones I interviewed (already started) that still need my scorecard
#   mine      ones I am an interviewer on
#
# `scope` narrows any tab further: "mine" keeps interviews I am on plus every interview for a job
# whose hiring team I am on (a recruiter owns the loop without sitting on each panel); "all" or
# nil keeps everything the tab returns.
class InterviewHub
  TABS = %w[upcoming schedule feedback mine].freeze
  SCOPES = %w[mine all].freeze

  def self.list(tab: nil, actor_id: Current.actor_id, scope: nil)
    rows = Interview.includes(:application).order(Arel.sql("starts_at IS NULL"), :starts_at, :created_at)
    rows = apply_tab(rows, tab.presence, actor_id)
    apply_scope(rows, scope.presence, actor_id).limit(200)
  end

  def self.apply_scope(rows, scope, actor_id)
    return rows if scope.nil? || scope == "all"
    raise ArgumentError, "unknown_scope:#{scope}" unless SCOPES.include?(scope)
    return rows.none if actor_id.blank?

    team_apps = Application.where(job_id: hiring_team_job_ids(actor_id)).select(:id)
    mine(rows, actor_id).or(rows.where(application_id: team_apps))
  end

  def self.hiring_team_job_ids(actor_id)
    HiringTeam.joins(:members).where(hiring_team_members: { user_id: actor_id }).select(:job_id)
  end

  def self.apply_tab(scope, tab, actor_id)
    return scope if tab.nil?
    raise ArgumentError, "unknown_tab:#{tab}" unless TABS.include?(tab)

    case tab
    when "upcoming"
      scope.where(status: "scheduled").where(starts_at: Time.current..)
    when "schedule"
      scope.where(status: %w[requested needs_attention])
           .or(scope.where.not(needs_attention_reason: [ nil, "" ]))
    when "mine"
      mine(scope, actor_id)
    when "feedback"
      submitted = Scorecard.where(user_id: actor_id, status: "submitted").select(:interview_id)
      mine(scope, actor_id).merge(Interview.feedback_open).where.not(id: submitted)
    end
  end

  # Active candidates whose current stage plans interviews that are not booked yet: the real
  # "to schedule" queue (no Interview row exists until someone books one). Mine = jobs I help hire for.
  def self.awaiting_schedule(actor_id: Current.actor_id, mine: false, limit: 100)
    apps = ResourceVisibility.applications.where(status: "active").includes(:pipeline, :job, :person)
    apps = apps.where(job_id: hiring_team_job_ids(actor_id)) if mine
    apps = apps.to_a
    booked = Interview.where(application_id: apps.map(&:id)).where.not(status: "cancelled")
                      .pluck(:application_id, :stage_key, :interview_key)
                      .group_by(&:first)
    apps.filter_map do |app|
      stage = app.pipeline&.stage(app.current_stage_key)
      plan = Array(stage&.dig("interviews"))
      next if plan.empty?
      have = Array(booked[app.id]).select { |row| row[1] == app.current_stage_key }.map(&:last)
      missing = plan.reject { |row| have.include?(row["key"]) }
      next if missing.empty?
      { app: app, stage: stage, missing: missing }
    end.sort_by { |row| row[:app].updated_at }.first(limit)
  end

  def self.mine(scope, actor_id)
    return scope.none if actor_id.blank?

    scope.where("JSON_CONTAINS(interviewer_user_ids, ?)", actor_id.to_json)
  end
end
