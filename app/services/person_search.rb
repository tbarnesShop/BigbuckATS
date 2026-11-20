# frozen_string_literal: true

# CRM people search: the one query behind the People list, saved searches, smart pools and bulk
# actions. Every filter is optional and they combine with AND.
#
#   q                       words, ALL must match somewhere: name, email, phone, headline, title, city,
#                           company, a tag, or a note
#   tag / not_tag           comma-separated tag names; a person needs every tag, and none of not_tag
#   source                  comma-separated (sourced, referral, applied, event, import, agent)
#   engagement_status       comma-separated (not_contacted, contacted, replied, interested, ...)
#   location                matches city, region or country
#   title, company          substring of the current title / a company the person is affiliated with
#   not_contacted_days      never contacted, or last contacted more than N days ago
#   contacted_within_days   contacted in the last N days
#   has_email               true / false
#   custom[<field key>]     a custom field value (text equals, or number equals)
#   lifecycle_stage, visibility, do_not_contact, owner_user_id, project_id (pool membership)
#   sort                    recent (default), name, activity, relevance (needs q)
class PersonSearch
  SORTS = %w[recent name activity relevance].freeze
  LIST_KEYS = %w[tag not_tag source engagement_status].freeze
  TAGGED_WITH = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM person_tags pt JOIN tags t ON t.organization_id = pt.organization_id AND t.id = pt.tag_id
              WHERE pt.organization_id = people.organization_id AND pt.person_id = people.id AND t.normalized_name = ?)
  SQL
  TAGGED_WITH_ANY = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM person_tags pt JOIN tags t ON t.organization_id = pt.organization_id AND t.id = pt.tag_id
              WHERE pt.organization_id = people.organization_id AND pt.person_id = people.id AND t.normalized_name IN (?))
  SQL
  SCALAR_KEYS = %w[q sort location title company not_contacted_days contacted_within_days has_email
                   lifecycle_stage visibility do_not_contact owner_user_id project_id].freeze

  # Request params -> plain filters hash, allowlisted (custom[<field key>] is a free-form map of scalars).
  def self.permitted_filters(raw)
    return {} if raw.blank?

    raw.permit(*SCALAR_KEYS, *LIST_KEYS, custom: {}).to_h
  end

  def self.call(viewer:, filters: {}, limit: 100, offset: 0)
    new(viewer: viewer, filters: filters, limit: limit, offset: offset).call
  end

  # Total matches for the same filters (for paging).
  def self.count(viewer:, filters: {})
    new(viewer: viewer, filters: filters, limit: 1, offset: 0).scope.count
  end

  def initialize(viewer:, filters:, limit:, offset: 0)
    @viewer = viewer
    @filters = (filters || {}).deep_stringify_keys
    @limit = [ [ limit.to_i, 1 ].max, 500 ].min
    @offset = [ offset.to_i, 0 ].max
  end

  def call
    ordered(scope).offset(@offset).limit(@limit)
  end

  def scope
    scope = PersonVisibility.scope_for(@viewer).not_merged.not_erased
    scope = apply_q(scope)
    scope = apply_tags(scope)
    scope = scope.where(lifecycle_stage: @filters["lifecycle_stage"]) if @filters["lifecycle_stage"].present?
    scope = scope.where(visibility: @filters["visibility"]) if @filters["visibility"].present?
    if @filters.key?("do_not_contact") && !@filters["do_not_contact"].nil? && @filters["do_not_contact"] != ""
      scope = scope.where(do_not_contact: ActiveModel::Type::Boolean.new.cast(@filters["do_not_contact"]))
    end
    scope = scope.where(owner_user_id: @filters["owner_user_id"]) if @filters["owner_user_id"].present?
    scope = scope.where(source: list("source")) if list("source").any?
    scope = scope.where(engagement_status: list("engagement_status")) if list("engagement_status").any?
    scope = apply_location(scope)
    scope = apply_title_and_company(scope)
    scope = apply_recency(scope)
    scope = apply_has_email(scope)
    scope = apply_custom(scope)
    if @filters["project_id"].present?
      scope = scope.where(id: ProjectMember.where(project_id: @filters["project_id"]).select(:person_id))
    end
    scope
  end

  private

  def list(key)
    @filters[key].to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def like(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.strip)}%"
  end

  def terms
    @terms ||= @filters["q"].to_s.split(/\s+/).map(&:strip).reject(&:blank?).first(8)
  end

  def apply_q(scope)
    terms.each do |term|
      pattern = like(term)
      scope = scope.where(<<~SQL.squish, *([ pattern ] * 9))
        people.display_name LIKE ? OR people.primary_email LIKE ? OR people.primary_phone LIKE ?
        OR people.headline LIKE ? OR people.current_title LIKE ? OR people.city LIKE ?
        OR EXISTS (SELECT 1 FROM person_tags pt JOIN tags t ON t.organization_id = pt.organization_id AND t.id = pt.tag_id
                   WHERE pt.organization_id = people.organization_id AND pt.person_id = people.id AND t.name LIKE ?)
        OR EXISTS (SELECT 1 FROM person_notes n WHERE n.organization_id = people.organization_id AND n.person_id = people.id AND n.body LIKE ?)
        OR EXISTS (SELECT 1 FROM companies c
                   WHERE c.organization_id = people.organization_id AND c.name LIKE ?
                     AND (c.id = people.current_company_id
                          OR EXISTS (SELECT 1 FROM person_affiliations a WHERE a.organization_id = people.organization_id
                                     AND a.person_id = people.id AND a.company_id = c.id AND a.current = 1)))
      SQL
    end
    scope
  end

  def apply_tags(scope)
    list("tag").each do |name|
      scope = scope.where(TAGGED_WITH, Tag.normalize_name(name))
    end
    excluded = list("not_tag").map { |name| Tag.normalize_name(name) }
    scope = scope.where.not(TAGGED_WITH_ANY, excluded) if excluded.any?
    scope
  end

  def apply_location(scope)
    return scope if @filters["location"].blank?

    pattern = like(@filters["location"])
    scope.where("people.city LIKE ? OR people.region LIKE ? OR people.country LIKE ?", pattern, pattern, pattern)
  end

  def apply_title_and_company(scope)
    scope = scope.where("people.current_title LIKE ?", like(@filters["title"])) if @filters["title"].present?
    if @filters["company"].present?
      pattern = like(@filters["company"])
      scope = scope.where(<<~SQL.squish, pattern, pattern)
        EXISTS (SELECT 1 FROM companies c
                WHERE c.organization_id = people.organization_id AND c.name LIKE ?
                  AND (c.id = people.current_company_id
                       OR EXISTS (SELECT 1 FROM person_affiliations a WHERE a.organization_id = people.organization_id
                                  AND a.person_id = people.id AND a.company_id = c.id AND a.current = 1)))
        OR EXISTS (SELECT 1 FROM person_affiliations a2 JOIN companies c2 ON c2.organization_id = a2.organization_id AND c2.id = a2.company_id
                   WHERE a2.organization_id = people.organization_id AND a2.person_id = people.id AND c2.name LIKE ?)
      SQL
    end
    scope
  end

  def apply_recency(scope)
    if @filters["not_contacted_days"].present?
      cutoff = @filters["not_contacted_days"].to_i.days.ago
      scope = scope.where("people.last_contacted_at IS NULL OR people.last_contacted_at < ?", cutoff)
    end
    if @filters["contacted_within_days"].present?
      scope = scope.where("people.last_contacted_at >= ?", @filters["contacted_within_days"].to_i.days.ago)
    end
    scope
  end

  def apply_has_email(scope)
    return scope unless @filters.key?("has_email") && @filters["has_email"].to_s != ""

    if ActiveModel::Type::Boolean.new.cast(@filters["has_email"])
      scope.where.not(primary_email: [ nil, "" ])
    else
      scope.where(primary_email: [ nil, "" ])
    end
  end

  def apply_custom(scope)
    (@filters["custom"] || {}).first(5).each do |key, value|
      next if value.blank?

      scope = scope.where(<<~SQL.squish, key.to_s, value.to_s, value.to_s)
        EXISTS (SELECT 1 FROM custom_field_values v JOIN custom_fields f ON f.id = v.custom_field_id
                WHERE v.organization_id = people.organization_id AND v.entity_type = 'Person' AND v.entity_id = people.id
                  AND f.entity = 'person' AND f.data_class = 'internal' AND f.`key` = ? AND (v.value_text = ? OR CAST(v.value_number AS CHAR) = ?))
      SQL
    end
    scope
  end

  def ordered(scope)
    case effective_sort
    when "name" then scope.order(:display_name, :id)
    when "activity" then scope.order(Arel.sql("people.last_activity_at IS NULL, people.last_activity_at DESC"), id: :desc)
    when "relevance" then scope.order(Arel.sql(relevance_sql), id: :desc)
    else scope.order({ created_at: :desc }, { id: :desc })
    end
  end

  def effective_sort
    sort = @filters["sort"].to_s
    return "recent" unless SORTS.include?(sort)

    sort == "relevance" && terms.empty? ? "recent" : sort
  end

  # Name hits outrank title/headline hits, which outrank everything else; ties fall to recent activity.
  def relevance_sql
    parts = terms.map do |term|
      pattern = ActiveRecord::Base.connection.quote(like(term))
      "(CASE WHEN people.display_name LIKE #{pattern} THEN 3 ELSE 0 END + " \
        "CASE WHEN people.current_title LIKE #{pattern} OR people.headline LIKE #{pattern} THEN 2 ELSE 0 END)"
    end
    "(#{parts.join(' + ')}) DESC, people.last_activity_at IS NULL, people.last_activity_at DESC"
  end
end
