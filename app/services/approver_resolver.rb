# frozen_string_literal: true

# Resolves step approver specs (role:, attribute:, user:) to user ids.
class ApproverResolver
  Resolved = Struct.new(:user_id, :from, keyword_init: true)

  def self.call(specs:, offer:, context_builder:, submitter_id: nil, allow_self_approval: false)
    new(
      specs: specs, offer: offer, context_builder: context_builder,
      submitter_id: submitter_id, allow_self_approval: allow_self_approval
    ).call
  end

  def initialize(specs:, offer:, context_builder:, submitter_id:, allow_self_approval:)
    @specs = Array(specs)
    @offer = offer
    @context_builder = context_builder
    @submitter_id = submitter_id
    @allow_self_approval = allow_self_approval
  end

  def call
    @specs.flat_map { |spec| resolve_one(spec.to_s) }
          .uniq(&:user_id)
          .reject { |r| !@allow_self_approval && r.user_id == @submitter_id }
  end

  private

  def resolve_one(spec)
    case spec
    when /\Arole:(.+)\z/
      role_key = Regexp.last_match(1)
      team = HiringTeam.find_by(job_id: @offer.application.job_id)
      return [] unless team

      team.members.where(team_role: role_key).map do |m|
        Resolved.new(user_id: m.user_id, from: spec)
      end
    when /\Aorg-role:(.+)\z/
      # Everyone in the organization with that role (e.g. org-role:owner), the usual fallback when a
      # job's hiring team has no one in the step's team role.
      role_key = Regexp.last_match(1)
      Membership.joins(:role).where(status: "active", roles: { key: role_key }).order(:created_at).map do |m|
        Resolved.new(user_id: m.user_id, from: spec)
      end
    when /\Aattribute:(.+)\z/
      path = Regexp.last_match(1)
      user_id = @context_builder.attribute_at(path)
      user_id.present? ? [ Resolved.new(user_id: user_id, from: spec) ] : []
    when /\Auser:(.+)\z/
      email_or_id = Regexp.last_match(1)
      user = User.find_by(id: email_or_id) || User.find_by(email: email_or_id)
      user ? [ Resolved.new(user_id: user.id, from: spec) ] : []
    else
      []
    end
  end
end
