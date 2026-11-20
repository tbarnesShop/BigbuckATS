# frozen_string_literal: true

# Lightweight funnel + sourcing analytics over live tables (no snapshot store yet).
class RecruitingAnalytics
  def self.funnel(job_id: nil)
    apps = Application.all
    apps = apps.where(job_id: job_id) if job_id.present?

    by_status = apps.group(:status).count
    by_stage = apps.where(status: "active").group(:current_stage_key).count
    transitions = StageTransition.where(subject_type: "Application")
    transitions = transitions.where(subject_id: apps.select(:id)) if job_id.present?
    stage_moves = transitions.where(command: "move").group(:to_stage_key).count

    {
      "applications_by_status" => by_status,
      "active_by_stage" => by_stage,
      "moves_into_stage" => stage_moves,
      "total_applications" => apps.count,
      "hired" => by_status["hired"].to_i,
      "rejected" => by_status["rejected"].to_i
    }
  end

  def self.sourcing
    enrollments = SequenceEnrollment.all
    by_status = enrollments.group(:status).count
    stopped = enrollments.where(status: "stopped").group(:stop_reason).count
    outbound = Communication.where(direction: "outbound").count
    replies = Communication.where(direction: "inbound").count
    referrals = Referral.group(:status).count

    {
      "enrollments_by_status" => by_status,
      "stop_reasons" => stopped,
      "outbound_messages" => outbound,
      "inbound_replies" => replies,
      "reply_rate" => outbound.zero? ? 0.0 : (replies.to_f / outbound).round(4),
      "referrals_by_status" => referrals,
      "active_sequences" => Sequence.where(status: "active").count
    }
  end
end
