# frozen_string_literal: true

# Deterministic first-pass classification of an inbound reply. Rules, not a model, so the result is
# explainable and the same everywhere; a recruiter or an agent can override it afterwards.
#
# The decision the label implies (opt-out, engagement status) is applied by .apply!, which both the
# inbound ingestor and the manual override go through.
class ReplyClassifier
  LABELS = %w[interested not_interested question unsubscribe out_of_office bounce other].freeze
  # Labels a person can be moved to by hand or by the classifier.
  OVERRIDABLE = (LABELS - %w[bounce]).freeze

  RULES = [
    [ "unsubscribe", /\b(unsubscribe|remove me|take me off|stop (emailing|contacting|messaging) me|do not (contact|email) me|don'?t (contact|email) me)\b/i ],
    [ "out_of_office", /\b(out of (the )?office|on (annual )?leave|automatic reply|auto-?reply|away until|back on (monday|tuesday|wednesday|thursday|friday|\d))\b/i ],
    [ "not_interested", /\b(not interested|no thanks|no thank you|not looking|not a (good )?fit|not open to|happy where i am|pass on this|i'?ll pass|not at this time|not right now)\b/i ],
    [ "interested", /\b(interested|sounds (great|good|interesting)|let'?s (chat|talk|connect|set up)|love to (chat|talk|hear|learn)|tell me more|happy to (chat|talk|connect)|open to (chatting|learning|(a |an )?(quick |short |brief )?(call|chat|conversation|talk))|send (me )?(more|details)|i'?m available|schedule a (call|time))\b/i ]
  ].freeze

  def self.classify(subject:, body:)
    text = strip_quoted(body.to_s)
    RULES.each { |label, pattern| return label if pattern.match?(text) || (label == "out_of_office" && pattern.match?(subject.to_s)) }
    text.include?("?") ? "question" : "other"
  end

  # Drops the quoted original so "Are you interested?" in the thread does not read as the reply.
  def self.strip_quoted(body)
    lines = []
    body.each_line do |line|
      break if line.match?(/\AOn .{5,120} wrote:\s*\z/) || line.start_with?("-----Original Message") || line.match?(/\AFrom:\s.+@/)

      lines << line unless line.start_with?(">")
    end
    lines.join
  end

  # Writes the label on the communication and applies what it implies for the person.
  def self.apply!(communication, label)
    raise ArgumentError, "unknown_classification" unless LABELS.include?(label)

    communication.update!(classification: label)
    person = communication.person
    case label
    when "unsubscribe"
      OptOut.add!(person: person, source: "reply")
    when "interested", "not_interested"
      decide!(person, label)
    end
    communication
  end

  def self.decide!(person, status)
    return if person.erased? || person.engagement_status == "do_not_contact"

    person.update_columns(engagement_status: status, updated_at: Time.current)
  end

  private_class_method :decide!
end
