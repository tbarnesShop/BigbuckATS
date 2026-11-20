# frozen_string_literal: true

# Opaque sync_token over updated_at+id for org-wide readers.
class SyncFeed
  def self.people(since_token: nil, limit: 100)
    new(entity: Person, since_token: since_token, limit: limit).page
  end

  def initialize(entity:, since_token:, limit:)
    @entity = entity
    @since = decode(since_token)
    @limit = limit
  end

  def page
    scope = (@entity == Person && Current.principal ? ResourceVisibility.people : @entity.all).order(:updated_at, :id)
    if @since
      scope = scope.where(
        "(updated_at > ?) OR (updated_at = ? AND id > ?)",
        Time.zone.parse(@since["updated_at"]),
        Time.zone.parse(@since["updated_at"]),
        @since["id"]
      )
    end
    records = scope.limit(@limit).to_a
    next_token = if records.any?
                   encode("updated_at" => records.last.updated_at.iso8601(6), "id" => records.last.id)
    else
                   @since_token_passthrough
    end
    {
      "data" => records.map { |r| serialize(r) },
      "sync_token" => next_token || encode("updated_at" => Time.current.iso8601(6), "id" => "")
    }
  end

  private

  def serialize(record)
    case record
    when Person
      {
        "id" => record.id,
        "display_name" => record.display_name,
        "primary_email" => record.primary_email,
        "source_system" => record.source_system,
        "source_id" => record.source_id,
        "updated_at" => record.updated_at.iso8601(6)
      }
    else
      { "id" => record.id, "updated_at" => record.updated_at.iso8601(6) }
    end
  end

  def encode(hash)
    Base64.urlsafe_encode64(hash.to_json)
  end

  def decode(token)
    return nil if token.blank?

    JSON.parse(Base64.urlsafe_decode64(token))
  rescue ArgumentError, JSON::ParserError
    nil
  end
end
