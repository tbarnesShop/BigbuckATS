# frozen_string_literal: true

# Writes the day's OutreachFunnel numbers for the org and for each sequence with enrollments.
# Idempotent per (scope, day): running it twice replaces the row.
class OutreachSnapshotter
  def self.call(day:)
    from = day.to_date.in_time_zone("UTC").beginning_of_day
    to = from + 1.day
    store(day.to_date, OutreachSnapshot::ORG, nil, OutreachFunnel.call(from: from, to: to))
    Sequence.find_each do |sequence|
      next unless SequenceEnrollment.where(sequence_id: sequence.id).exists?

      store(day.to_date, "seq:#{sequence.id}", sequence.id, OutreachFunnel.call(from: from, to: to, sequence_id: sequence.id))
    end
  end

  def self.store(day, key, sequence_id, metrics)
    row = OutreachSnapshot.find_or_initialize_by(scope_key: key, snapshot_on: day)
    row.update!(sequence_id: sequence_id, metrics: metrics)
  end

  private_class_method :store
end
