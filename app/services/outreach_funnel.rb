# frozen_string_literal: true

# Outreach numbers for a time window, org-wide or for one sequence: who was enrolled, contacted,
# replied (and how the replies were classified), and who went on to apply or be hired.
# Everything counts distinct people, so a three-step sequence is one contact, not three.
class OutreachFunnel
  REPLY_LABELS = %w[interested not_interested question unsubscribe other].freeze
  NON_REPLY_LABELS = %w[out_of_office bounce].freeze

  def self.call(from:, to:, sequence_id: nil)
    new(from: from, to: to, sequence_id: sequence_id).call
  end

  def initialize(from:, to:, sequence_id:)
    @from = from
    @to = to
    @sequence_id = sequence_id
  end

  def call
    contacted_ids = contacted_person_ids
    replies = inbound.where(person_id: person_scope(contacted_ids)).group(:classification).distinct.count(:person_id)
    replied = REPLY_LABELS.sum { |l| replies[l].to_i }
    # Same person can appear under two labels over time; the headline is distinct people.
    replied_people = inbound.where(person_id: person_scope(contacted_ids)).where.not(classification: NON_REPLY_LABELS)
                            .or(inbound.where(person_id: person_scope(contacted_ids), classification: nil)).distinct.count(:person_id)
    # Applied after being contacted: an application that predates the first outreach is not its result.
    applications = Application.where(person_id: contacted_ids, created_at: @from...@to)
                              .where("applications.created_at >= (SELECT MIN(c.created_at) FROM communications c WHERE c.person_id = applications.person_id AND c.direction = 'outbound' AND c.organization_id = applications.organization_id)")
    {
      "from" => @from.iso8601, "to" => @to.iso8601, "sequence_id" => @sequence_id,
      "enrolled" => enrollments.where(created_at: @from...@to).distinct.count(:person_id),
      "contacted" => contacted_ids.size,
      "replied" => replied_people,
      "reply_rate" => contacted_ids.empty? ? 0.0 : (replied_people.to_f / contacted_ids.size).round(4),
      "by_classification" => (REPLY_LABELS + NON_REPLY_LABELS).index_with { |l| replies[l].to_i },
      "positive_replies" => replies["interested"].to_i + replies["question"].to_i,
      "applied" => applications.distinct.count(:person_id),
      "hired" => applications.where(status: "hired").distinct.count(:person_id),
      "replied_by_label_sum" => replied
    }
  end

  private

  def enrollments
    scope = SequenceEnrollment.all
    @sequence_id ? scope.where(sequence_id: @sequence_id) : scope
  end

  def inbound
    Communication.where(direction: "inbound", created_at: @from...@to)
  end

  # Replies only count for people who were contacted in-window. Enrollment alone is not enough:
  # otherwise a sequence scoped report can show replied > contacted.
  def person_scope(contacted_ids)
    contacted_ids
  end

  def contacted_person_ids
    if @sequence_id
      # Prefer communication timestamps so seed backdating and live sends agree with org-wide counts.
      sent = Communication.where(
        direction: "outbound", created_at: @from...@to, sequence_enrollment_id: enrollments.select(:id)
      ).distinct.pluck(:person_id)
      return sent if sent.any?

      ScheduledMessage.where(
        status: "sent", sent_at: @from...@to, sequence_enrollment_id: enrollments.select(:id)
      ).distinct.pluck(:person_id)
    else
      # Outreach only: sequence steps and one-off messages. Typed hiring mail (application
      # confirmations, scheduling, offers) goes to candidates and is not sourcing.
      outbound = Communication.where(direction: "outbound", created_at: @from...@to)
      outbound.where.not(sequence_enrollment_id: nil)
              .or(outbound.where(message_type: [ nil, "", "outreach" ]))
              .distinct.pluck(:person_id)
    end
  end
end
